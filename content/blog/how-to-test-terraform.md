+++
title = "Як треба тестувати Terraform"
date = "2022-07-19"
+++

> Спочатку тут була одна велика стаття про тестування тераформу з теоретичними викладками, схибленою логікою та прикладами. Я вирішив поділити її на шматочки, щоб вам, мої любі кошенята, було зручніше їх їсти. 


Ця стаття є про те **як саме треба** тестувати тераформ. Чомусь багато хто не робить цього правильно і я не знаю чому. Я не буду зараз розповідати як тераформ тестувати не треба, бо вже зробив це 
[ось тут](/posts/how-not-to-test-terraform/). 

# Нащо воно тобі?

Ну усі розумні: хочу шоб інфраструктура не ламалася і ще царицею морською, і шоб ліхтарики мерехтіли сріблястим сяйвом, а я — маленький і безтурботний — бігаю без штанів і усі мені радіють та посміхаються. 

Але тестування — то не якась тобі золота рибка. І без штанців бігати можна тільки по нудистському пляжу чи у себе у спальні, та й то лише в перші два роки шлюбу.

А коли ти пишеш **програму на мові terraform**, треба бути впевненими що програма не лише працює, а працює саме так, як було задумано. І якщо хтось буде вносити зміни до цієї програми, вона буде продовжувати працювати саме так і ніяк інакше.

Ми в жодному разі **не тестуємо інфраструктуру**. То вже інша проблема, інший топік. А ця стаття лише про те як тестувати програми, написані на тераформі. 

# Занурюємось у схибленний світ прикладів

Нехай існує Софія. Софія працює у великій компаніі, получає ну не велетеньску, але зарплатню, шось знає, шось не знає. Звичайний розумний девопс.

І ось одного разу їй дали задачу — написати тераформ код, який створює... ну най буде кубернетіс кластери для різних команд у її великій компанії. 

Міссія дуже важлива, бо зверху десь почули (чи то я їм сказав), що окремі кластери для команд то дуже зручно і вирішить усі їх проблеми. 

Але для кожного кластера є потреба в імені. Софія запитала, які саме повинні бути імена, і після виснажливої наради на 25 людей, котра тривала 5 годин, усі *дійшли згоди* що іменування повинно бути таке:

```
<ім’я кластеру>.<ім’я департаменту>.<оточення>.example.com
``` 

У кожному департаменті є якісь там свої команди, тому призначили відповідального менеджера С-левела, котрий кожен день о дев’ятій ранку оновлюватиме json файлик з мапінгом назв команд до назв департаментів в Amazon SSM (хто не зна, то такий сервіс у якому зручно щось тримати, наприклад конфіги)

# Продовжуємо занурення

Софія почухала макітру, закатала рукави і почала програмувати тераформ. 

Спочатку вона вичитала дані з AWS SSM:

```tf
// Gets data in the format of:
// {
//   "staging": "stage.example.com",
//   "canary": "preprod.example.com",
//   "production": "prod.example.com"
// }
data "aws_ssm_document" "domain_mapping" {
  name            = "AWS-EnvMapping"
  document_format = "JSON"
}


// Gets the mapping of sub-team to the bigger team
// {
//   "datateam": ["ml", "ml-frontend", "bisops"],
//   "backend": ["javaheads", "someonewholovehaskell", "api"],
//   "frontend": ["react", "fullstack", "jinjaninja"],
// }
data "aws_ssm_document" "team_mapping" {
  name            = "AWS-TeamMapping"
  document_format = "JSON"
}
```

А після цього написали логіку у locals 

```tf
locals {
  // Перетравлюємо json на щось з чим можна працювати
  domain_mapping = jsondecode(data.aws_ssm_document.domain_mapping.content)
  team_mapping = jsondecode(data.aws_ssm_document.team_mapping.content)
  // Перевертаємо мапінг догори ногами, так щоб по імені команди знайти департамент
  department = transpose(local.team_mapping)[var.team_name][0]
  // Шукаємо потрібний нам домен вищого рівня в мапінгу оточень
  current_env_domain = local.domain_mapping[var.env]
  // Створюємо домен для майбутнього кластеру
  domain = "${var.cluster_name}.${local.department}.${local.current_env_domain}.example.com"
}
```


# Тестуємо імперативну логіку

Наша Софія — дуже гарний інженер, тому вона вирішила відразу починати тестування, а не писати спочатку простирадло, а потім думати що з ним робити. Також їй дуже пощастило, що вона ніколи не постила "навіщо девопсам програмування" у різні чатики, а просто навчилася деяким мовам. 

Завдяки цьому, вона швидко зрозуміла що блок `locals` то є *імперативна функція*, а сам тераформ — суміш програмування у **імперативному** та **декларативному** стилі. 

А що роблять ~~у тюрячкє~~ з імперативними функціями для тестування? Правильно, їх розбивають на шматки і стараються довести до [чистих функцій](https://en.wikipedia.org/wiki/Pure_function)

## Виносимо логіку

Але у тераформі ж нема якоїсь можливості написати `func name() -> result {}`! Ну нема й нема. Але девопси — люди з хворою уявою, тому замість функцій Софія вирішила використати модулі: створила піддіректорію з назвою parse_domain і вже у ній — файли 

```tf
// vars.tf 

variable "team_mapping_json" {
  type = string
  description = "JSON string containing the team mapping"
}

variable "domain_mapping_json" {
  type = string
  description = "JSON string containing the domain mapping"
}

variable "env" {
  type = string
  description = "The environment we need to choose from the list of available environments"
}

variable "team_name" {
  type = string
  description = "The team name we need to choose from the list of available teams"
}

variable "cluster_name" {
    type = string
    description = "The cluster name"
}

//  main.tf

locals {
  // Перетравлюємо json на щось з чим можна працювати
  domain_mapping = jsondecode(var.domain_mapping_json)
  team_mapping = jsondecode(var.team_mapping_json)
#  // Перевертаємо мапінг догори ногами, так щоб по імені команди знайти департамент
  department = transpose(local.team_mapping)[var.team_name][0]
#  // Шукаємо потрібний нам домен вищого рівня в мапінгу оточень
  current_env_domain = lookup( local.domain_mapping, var.env)
#  // Створюємо домен для майбутнього кластеру
  domain = "${var.cluster_name}.${local.department}.${local.current_env_domain}.example.com"
}

// outputs.tf

output "domain" {
  value = local.domain
  precondition {
    error_message = "local domain must contain valid domain symbols"
    condition = can(regex("^([-a-zA-Z0-9]+\\.){4}+com", local.domain))
  }
}
```

Тобто, фактично в неї з’явився модуль, котрий ізолює логіку у собі та не потребує багацько часу на тести. Якщо б вона не виносила логіку, то їй було б треба кожен раз підіймати увесь кластер, а ще якось запихувати данні у SSM просто щоб дізнатись як код себе поводить з невалідним інпутом. 

Також, самі кмітливі з вас помітили, що Софія одразу зробила валідацію вихідніх данних частиною своєї програми. Вона це зробила в першу чергу для того щоб помилки були більш зрозумілі і красивіші. Бо завжди гарно коли помилки зрозумілі. 

## Починаємо тестування 

Тепер, коли логіка ізольована — її можна тестувати. 

Перед тим як писати код, Софія вирішила десь на папері записати кейси, які треба покрити:

* успішний сценарій — ім’я генерується як треба
* невдалі сценарії:
	* якщо тіми не існує у списках
	* ящко тіма з тим самим іменем існує у двох департаментах
	* якщо оточення не існує у списках
	* якщо передали невалідний json
	* якщо ім’я вийде не валідною урлою
	* інші

## terraform test - success
Софія знала про багато інтрументів для тестування тераформу, але спочатку вирішила використати експериментальне [тестування](https://www.terraform.io/language/modules/testing-experiment) самого тераформу. 

Хоча вона і була дуже скептично налаштована, але ідея тестування стандартними інструментами через команду `terraform test` приваблювала нашу Софію, як метелика вогник. 

Тому вона зробила директорію `test/parse_domain_success` і у ній файл `main.tf`

```tf
terraform {
  required_providers {
    test = {
      source = "terraform.io/builtin/test"
    }
  }
}

module "parse_domain" {
  source = "../../parse_domain"
  cluster_name = "example"
  domain_mapping_json = <<-EOF
    {
      "staging": "stage.example.com",
      "canary": "preprod.example.com",
      "production": "prod.example.com"
    }
    EOF
  env = "staging"
  team_mapping_json = <<-EOF
      {
        "datateam": ["ml", "ml-frontend", "bisops"],
        "backend": ["javaheads", "someonewholovehaskell", "api"],
        "frontend": ["react", "fullstack", "jinjaninja"]
      }
    EOF
  team_name = "ml"
}

resource "test_assertions" "domain" {
  component = "domain"
  equal "domain" {
    description = "domain should be example.datateam.stage.example.com"
    got         = module.parse_domain.domain
    want        = "example.datateam.stage.example.com"
  }
}
```

Після цього запустила `terraform test` і — диво, усе працює з першого разу! 

## terraform test - fail

Але халепа спіткала Софію коли вона почала запроваджувати негативні сценарії. 

Логіка функції-модуля `parse_domain` — падати, коли щось не так з данними. Наприклад, якщо `cluster_name = @@@__!@#!`, чи був переданий невалідний json. 

Але, як і багато чого у житті, тераформ **не покрива** негативні сценарії. Коли модуль падає з помилкою — тести, як матроси на кораблі, йдуть на дно за ним. 

> У майбутнєму команда тераформа якось хоче це змінити, але принаймні у версії v1.2.4 негативні тести не працюють. 

Тому використовувати `terraform test` можна **тільки** у випадках коли ви некомпетентні. 

## terratest

А наша Софія — дуже досвічений інженер. Тому вона просто використала [terratest](https://terratest.gruntwork.io)

Спочатку покрила *успішний* сценарій: 

```go
package tests

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestParseDomainSuccess(t *testing.T) {
	// retryable errors in terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../parse_domain/",
		Vars: map[string]interface{}{
			"domain_mapping_json": `{ 
				"staging": "stage.example.com", 
				"canary": "preprod.example.com", 
				"production": "prod.example.com" 
			}`,
			"team_mapping_json": `{
				"datateam": ["ml", "ml-frontend", "bisops"],
				"backend": ["javaheads", "someonewholovehaskell", "api"],
				"frontend": ["react", "fullstack", "jinjaninja"]
			}`,
			"env":          "staging",
			"team_name":    "ml",
			"cluster_name": "claster1",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	output := terraform.Output(t, terraformOptions, "domain")
	assert.Equal(t, "claster1.datateam.stage.example.com", output)
}
```

А потім і *негативний* сценарій з невалідним іменем: 

```go
.....		
			"cluster_name": "!@#!@#__",
		},
	})

	_, err := terraform.InitE(t, terraformOptions)
	assert.Nil(t, err)
	_, err = terraform.ApplyE(t, terraformOptions)
	assert.Error(t, err)
}

```

А за ним і решту.
 
# Тестування ресурсів

Тестування ресурсів то є антипаттерн, бо ресурси декларативні. [Ось тут](/posts/how-not-to-test-terraform/) я більш детально про це розповів. 

Але хашикорп не були б хашикорпом, якщоб не здійснили спробу спотворити декларативну логіку у імперативну. 

Тому у нас є декларативні функції з імперативною поведінкою, а саме: 

* template
* блоки з `for_each`
* local-exec
* блоки з dynamic
* та багато інших

І деякі з них попалися і Софії. Плак-плак. 

## Тестування плану

І якщо якісь там локалекзеки можна затестувати з аплаєм, то dynamic блоки то вже інша чехарда. 

Проте Софія не така нюня, як я, тому вона швидко винесла ці блоки у окремий модуль: 

```
variable "inbound_ports" {
  type = list(number)
}

resource "aws_security_group" "web" {
  vpc_id = var.vpc_id
  name = "webserver"
  dynamic "ingress" {
    for_each = var.inbound_ports
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/32"]
    }
  }
}
```

Проте, просто так застосувати його було не можна, так як ресурси потребують провайдера — тому вона чи засунула провайдер у модуль, чи написала додадковий модуль враппер для тестів де вже задефайнила провайдера, то я вже не пам’ятаю. Але обидва варіанти мають право на ~~поплаву~~ життя. 

Після цього Софія протестувала план:

```go

package tests

import (
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestSGDynamicSuccess(t *testing.T) {
	exampleFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "sg_dynamic/")
	planFilePath := filepath.Join(exampleFolder, "plan.out")
	// retryable errors in terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../sg_dynamic/",
		Vars: map[string]interface{}{
			"inbound_ports": []int{80, 443},
			"vpc_id": "non-exist"
		},
		PlanFilePath: planFilePath,
	})

	defer terraform.Destroy(t, terraformOptions)

	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_security_group.web")
	sgResource := plan.ResourcePlannedValuesMap["aws_security_group.web"]
	ingress_dyn := sgResource.AttributeValues["ingress"].([]interface{})
	assert.Equal(t, ingress_dyn[0].(map[string]interface{})["from_port"], float64(443))
	assert.Equal(t, ingress_dyn[0].(map[string]interface{})["to_port"], float64(443))
	assert.Equal(t, ingress_dyn[1].(map[string]interface{})["from_port"], float64(80))
	assert.Equal(t, ingress_dyn[1].(map[string]interface{})["to_port"], float64(80))
}

```

Також вона прописала у коді ще багато різних fail тестів, як ото якщо передати однакові порти чи взагалі нічого передавати. 

Тестування плану замість тестування аплаю допомогло Софії зробити тести швидкими та тестувати наміри програми, що і було треба, бо майже завжди цього достатньо. 

# Висновки

Отже, які висновки ми можемо зробити з прикладу Софії? 

1. Треба тестувати лише ту логіку що ми самі пишемо
2. Якщо це можливо, слід ізолювати логіку в швидкі locals
3. Модулі — гарна абстракція для внутрішньої логіки
4. Тестувати треба не тільки success, але й fail сценрії
5. Якщо треба тестувати ресурси — тестувати план, а не аплай
6. Краще юзати `terratest`, ніж `terraform test`


В тестуванні тераформу ще багато усього цікавого, наприклад тестування змін, тестування великих модулів, чи тестування інфраструктури. Якщо цікаво — пишіть у коментарях. 

{{tg(id="UkropsDigest/522")}}
