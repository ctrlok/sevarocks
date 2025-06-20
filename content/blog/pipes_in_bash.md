+++
title = "Пайпи, баш і конкурентність"
date = "2024-05-12"
+++

Років десь 15 потому я ~~був дурний і~~ любив лишати на співбесідах одне-два питання по башу. Це дещо бісило усіляких sinior YAML engineer, але мені було цікаво наскільки люди розуміють (чи не розуміють) інструменти які використовують щодня.

Я знаю, *знаю*, баш як мова це стрьом і спроектовано дуже давно, людьми, які жили при фараонах [^1 left] і зараз вже спочивають у пірамідах. 

[^1 left]: Це пояснює деякі античні знахідки: 
    
    ![/images/bash/pyr.jpg](/images/bash/pyr.jpg)

Але вислухайте мене. Люди які писали баш були **розумними** людьми. І вони робили **цікаві** і *практичні* речі. Дуже багато цікавих і практичних речей. 

І я вже давно не задаю питання по башу. Але досі ~~дурний і~~ отримую задоволення від гарно написаного скрипта, реалізація якого в іншій мові була б складнішою.

### Задача

Правдами і неправдами в мене з’явилась задача виконати пайплайн операцій над списком. Для простоти і розуміння [^2 right] нехай це буде: 

1. Збілдити Docker-імеджі з переліку.
2. Запушити їх в різні реджестрі.
3. Після того як імедж запушився в усі реджестрі — смикнути вебхук.

{% mermaid() %}
---
config:
    theme: neo
    look: neo
    layout: dagre
---
flowchart LR
    list["List of Images"] --> build["docker build"]
    build --> worker1["push worker 1"] & worker2["push worker 2"]
    worker1 --> webhook["webhook"]
    worker2 --> webhook
    list@{ shape: procs}
    style list fill:#f9f,stroke:#FFCDD2
    style build fill:#C8E6C9
    style webhook stroke:#BBDEFB,stroke-width:1px,stroke-dasharray: 1,fill:#BBDEFB

{% end %}

[^2 right]: До речі, класно пушити у різні реджестрі можна за допомогою 
    [regctl](https://github.com/regclient/regclient/blob/main/docs/regctl.md),
    але не в моєму випадку, тому що мені було потрібно: 

    1. Збілдити досить великі Docker-імеджі з нейронками.
    2. Експортнути їх в формат OCI (за допомогою `skopeo`)
    3. З OCI перевести їх в формат віддаленного реджестрі.
    4. Зробити rclone блобів в декілька віддаленних реджестрі по всьому світу .
    5. Перевести їх назад в OCI (щоб `skopeo` мало змогу перевикористати блоби)
    6. Запушити імеджи в реджестрі (щоб оновити віддалені маніфести під вже запушені блоби)

    Обмеження
    * Білдити і експортити тільки один імедж одночасно.
    * Пушити тільки один імедж одночасно.

    Але чим детальніший приклад, тим менша вірогідність що хтось витратить час на його розуміння. 


Усе просто, і в наївному варіанті це виглядає приблизно так:

```bash
#!/bin/bash -e

images=("image1" "image2" "image3")

for image in "${images[@]}"; do
  docker build -t "registry-1/$image" -t "registry-2/$image" .
  docker push "registry-1/$image"
  docker push "registry-2/$image"
  curl -X POST "https://example.com/webhook/$image"
done
```


Але це не оптимальна реалізація, тому що: 
* можна білдити image2, доки пушимо image1 (асинхронність)
* можна пушити імеджі в обидва реджестрі паралельно

> [!WARNING]
> 
> Асинхронність ⊆ конкурентність і майже завжди — **оптимізація**. І нема нічого гірше в інфраструктурі ніж *передчасна оптимізація*. 
> Натомість **наївність** майже завжди **достатня** сама по собі: чим простіша ідея, тим легше її читати і підтримувати. 
> 
> Якщо мінуси наївного підходу не критичні, то __завжди__ варто обирати наївний підхід із мінімумом оптимізацій. 
> 
> Пам’ятайте: ваш код може колись прочитати джаваскріпт розробник і померти. 

### Конкурентність


В баші досить просто запустити конкурентні задачі якщо додати символ `&` в кінець строки: 

```bash
# Ця задача запускається у фоні  
some_task &  

# І ця також  
(  
    other_task  
    sleep 200  
    some_webhook  
)&  

# Ми можемо очікувати завершення задачі, знаючи її PID  
last_task_pid=$!  
wait $last_task_pid  

# Або можемо чекати, поки виконається все, що запущено у фоні  
wait  
```

Тобто, якщо б в нас були фунції `docker_build`, `docker_push` та `webhook` [^3 right] ми могли б зробити щось на кшталт цього

[^3 right]: Для простоти дебагу і тестування ми не будемо білдити і пушити кожного разу, а зробимо mock функції:
    ```bash
    function docker_build() {
        echo Start build for $1
        sleep 0.3
        echo End build for $1
    }
    
    function docker_push() {
        echo Start push for $1
        sleep $2
        echo End push for $1
    }
    
    function webhook() {
        echo Start webhook for $1
        sleep 0.1
        echo End webhook for $1
    }
    
    # і треба не забути їх ексопртувати
    export -f docker_build
    export -f docker_push
    export -f webhook
    ```
    У майбутньому ми просто замінимо тіло функції на щось валідне, а поки що матимемо змогу додати будь-який лог і навіть протестувати логіку. (Хоча тестування bash-скриптів — це тема для окремого поста.)



```bash
docker_build &
docker_push reg1/$image &
docker_push reg2/$image &
webhook $image &
wait
```

Але як передати інформацію від процеса білдера до процесів які пушать і процесів вебхуків? 

### Пайпи

Ми знаємо, що якщо написати `ls | grep`, то всі дані, які `ls` надрукує в `stdout`, підуть до команди `grep`.  

Це відбувається тому, що кожен процес у Linux типово має щонайменше три відкритих файлових дескриптори (якщо потім самостійно їх не закриє):  
- `stdin` (0),  
- `stdout` (1),  
- `stderr` (2).  

Пайпи — це просто перенаправлення даних з одного дескриптора в інший.  

Ми могли б замість пайпів використати і файли, але пайпи зручні тим, що це ще й інструмент синхронізації: коли пайп закривається, процес, який з нього читає, розуміє, що більше інформації немає, і може спокійно "повзти в помиральну яму".  

Щоб краще зрозуміти пайпи, рекомендую почитати [код в ядрі](https://github.com/torvalds/linux/blob/059dd502b263d8a4e2a84809cf1068d6a3905e6f/fs/pipe.c) і подивитися, як можна імплементувати bash-пайпи в простій програмі на C.

{% folded(title='Приклад імплементації пайпів на C') %}

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main() {
    int pipefd[2];
    pid_t pid1, pid2;

    // Створюємо пайп
    if (pipe(pipefd) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }

    // Створюємо child process
    pid1 = fork();
    if (pid1 == -1) {
        perror("fork");
        exit(EXIT_FAILURE);
    }

    if (pid1 == 0) { // Child 1 (Writer)
        // Close the read end of the pipe
        close(pipefd[0]);

        // Redirect standard output to the write end of the pipe
        dup2(pipefd[1], STDOUT_FILENO);

        // Close the original write end of the pipe (important!)
        close(pipefd[1]);

        // Execute a command or perform some action that writes to stdout
        // Example:
        execlp("ls", "ls", "-l", NULL); // List files in long format
        perror("execlp"); // Only reached if execlp fails
        exit(EXIT_FAILURE);
    }

    // Create the second child process
    pid2 = fork();
    if (pid2 == -1) {
        perror("fork");
        exit(EXIT_FAILURE);
    }

    if (pid2 == 0) { // Child 2 (Reader)
        // Close the write end of the pipe
        close(pipefd[1]);

        // Redirect standard input to the read end of the pipe
        dup2(pipefd[0], STDIN_FILENO);

        // Close the original read end of the pipe (important!)
        close(pipefd[0]);

        // Execute a command or perform some action that reads from stdin
        // Example:
        execlp("wc", "wc", "-l", NULL); // Count lines from input
        perror("execlp"); // Only reached if execlp fails
        exit(EXIT_FAILURE);
    }

    // Parent process (Closes both ends of the pipe)
    close(pipefd[0]);
    close(pipefd[1]);

    // Wait for both child processes to finish
    waitpid(pid1, NULL, 0);
    waitpid(pid2, NULL, 0);

    printf("Parent process finished.\n");

    return 0;
}
```

Збілдити можна так: 
```bash
gcc filename.c -o filename
./filename
```
    
{% end %}

В нашому прикладі було потрібно розпочати `docker push` після того як пройшов `docker build` , тобто написати в два процесси з першого. 

Це можна зробити так: 

```bash
(echo "to_stdout"; echo "to_stderr" >&2) \
  2> >(xargs -I{} echo "from_stderr:{}") \
  1> >(xargs -I{} echo "from_stdout:{}")
```

Чи використовуючи `tee(1)`

```bash
echo "image" | tee >(xargs -I{} echo "from_tee:{}") | xargs -I{} echo "from_tee2:{}"
```

Але простіше для читання і розуміння буде якщо ми використаємо іменовані пайпи [^4 left]. 

[^4 left]: У прикладі далі ви побачите `exec 3>/tmp/reg1.fifo` — це перенаправлення третього (нового) файлового дескриптора в іменований пайп.  

    І це зроблено не для того, щоб заплутати читача, а для того, щоб відкрити пайп лише один раз і тримати його відкритим.


```bash
# Створюємо іменовані пайпи для пушерів
mkfifo /tmp/reg1.fifo
mkfifo /tmp/reg2.fifo

# Запускаємо воркера який білдить імеджі
(
	# Перенаправляємо дескриптори в пайпи
	exec 3>/tmp/reg1.fifo
	exec 4>/tmp/reg2.fifo
	
	# Білдимо імеджі
	for i in $LIST; do
	  docker_build ${i}
	  
	  # Пишемо про успіх в пайпи
	  echo ${i} >&3
	  echo ${i} >&4
	done
	
	# Коли всі імеджі збілджені — закриваємо пайпи 
	exec 3>&-
	exec 4>&-
	# І видаляємо їх
	rm /tmp/reg1.fifo /tmp/reg2.fifo
)& # `&` значить що ми запускаємо в фоні

# Використовуємо xargs щоб не блокувати docker_build воркера
# Без xargs буде блокування
xargs -n1 -I{} bash -c "docker_push reg1/{}" < /tmp/reg1.fifo &
xargs -n1 -I{} bash -c "docker_push reg2/{}" < /tmp/reg2.fifo &

# Чекаємо доки завершаться усі процесси
wait
```

Таким чином ми у фоні запустили процес, який незалежно білдить імеджі, і крізь пайпи сповіщає інші два процеси, які по одному, незалежно один від одного, пушать імеджі до реєстрів.  

Усе, що залишилося, — це сповістити про успіх і зробити вебхук.  

# Синхронізація незалежних процесів

Якщо те, що було вище, здалося вам оверінженерингом, то заплющуйте очі.  

Як є багато способів освіжувати кота, так і синхронізувати [^5 right] потоки можна декількома способами: за допомогою сигналів і команди `trap`, за допомогою лок-файлів, команди `wait` або пайпів.  

[^5 right]: Синхронізація не те щоб потрібна в цьому прикладі, тому ми могли б просто смикнути всі вебхуки після команди `wait`, тобто коли ми вже точно впевнені, що все запушено. Але можуть бути інші задачі, коли треба щось запустити після кожної ітерації, а не після всіх.  

Як на мене, пайпи — це найпростіша і найшвидша реалізація, але якщо вам цікаві інші способи (або ви знаєте ще щось), залишайте коментарі.  

#### Синхронізація пайпами  

Що ми знаємо про пайпи? Ну, як мінімум, що якщо ми намагаємося прочитати з пайпа, у який ніхто не пише, то будемо чекати вічність.  

```bash
#!/usr/bin/env bash

mkfifo /tmp/pipe
(
  echo "I'm waiting for pipe"
  < /tmp/pipe
  echo "I'm done waiting for pipe"
)&

sleep 1
echo "I'm going to write to pipe"
echo > /tmp/pipe
sleep 1
echo "I'm done writing to pipe"

# Result:
# I'm waiting for pipe
# I'm going to write to pipe
# I'm done waiting for pipe
# I'm done writing to pipe
```

Це працює з одним процессом, а як зробити з двома? Тут вже не вийде просто очікувати пайп, бо можна залочити самих себе. Ось приклад як перший процесс очікує поки хтось напише в pipe1, в той час як другий процес очікує доки хтось прочитає pipe2

```bash
#!/usr/bin/env bash

mkfifo /tmp/pipe1
mkfifo /tmp/pipe2
(
  < /tmp/pipe1
  < /tmp/pipe2
)&

echo > /tmp/pipe2
echo > /tmp/pipe1
```

Вихід з цієї ситуації — запустити очікування пайпів в окремих процесах і очікувати на завершення цих процесів: 

```bash
mkfifo /tmp/pipe1
mkfifo /tmp/pipe2
(
  cat < /tmp/pipe1 &
  pid1=$!
  cat < /tmp/pipe2 &
  pid2=$!
  wait $pid1 $pid2
  echo "I'm done with pipes!"
)&

echo > /tmp/pipe2
echo > /tmp/pipe1
```

## Додаємо очікувач на вебхук

Тепер кожен раз коли ми білдимо імедж ми відразу створюємо пайпи для очікування і запускаємо очікувач, який буде тупити доки ніхто не напише в обидва пайпи. 

```bash
for i in $LIST; do
  docker_build ${i}
  
  # Створюємо пайпи очікування під кожен імедж
  mkfifo /tmp/reg1-${i}.fifo
  mkfifo /tmp/reg2-${i}.fifo
  
  # Після кожного білда запускаємо воркер вебхуку
  # який очікує коли імеджі запушать
  (
    # І запускаємо очікувачі в фоні 
    cat /tmp/reg1-${i}.fifo &> /dev/null &
    # Записуємо PID очікувача
    wait_for_reg1=$!
    
    cat /tmp/reg2-${i}.fifo &> /dev/null &
    wait_for_reg2=$!
    
    # Очікуємо на обидва очікувача
    wait $wait_for_reg1 $wait_for_reg2
    
    # виконуємо вебхук
    webhook ${i}
    # І чистимо їх після себе
    rm /tmp/reg1-${i}.fifo /tmp/reg2-${i}.fifo
  )&
  
  echo ${i} >&3
  echo ${i} >&4
done
exec 3>&-
exec 4>&-
rm /tmp/reg1.fifo /tmp/reg2.fifo
)&

# Оновлюємо команду — додаємо нотифікацію для вебхука
# після того як запушили імедж
xargs -n1 -I{} bash -c "docker_push reg1/{}; echo > /tmp/reg1-{}.fifo" < /tmp/reg1.fifo &
xargs -n1 -I{} bash -c "docker_push reg2/{}; echo > /tmp/reg2-{}.fifo" < /tmp/reg2.fifo &
wait
```

Таким чином процеси які пушать — незалежно один від одного сповіщують процес вебхука про своє завершення і не блокуються. 

# Результат

Ось щось таке мало в нас вийти. 

```bash
#!/usr/bin/env bash

LIST="image1 image2 image3"

function docker_build() {
    echo Start build for $1
    sleep 1.5
    echo End build for $1
}

function docker_push() {
    echo Start push for $1
    sleep $2
    echo End push for $1
}

function webhook() {
    echo Start webhook for $1
    sleep 0.1
    echo End webhook for $1
}

export -f docker_build
export -f docker_push
export -f webhook

mkfifo /tmp/reg1.fifo
mkfifo /tmp/reg2.fifo
(
exec 3>/tmp/reg1.fifo
exec 4>/tmp/reg2.fifo
for i in $LIST; do
  mkfifo /tmp/reg1-${i}.fifo
  mkfifo /tmp/reg2-${i}.fifo
  docker_build ${i}
  (
    cat /tmp/reg1-${i}.fifo &> /dev/null &
    wait_for_reg1=$!
    cat /tmp/reg2-${i}.fifo &> /dev/null &
    wait_for_reg2=$!
    wait $wait_for_reg1 $wait_for_reg2
    webhook ${i}
    rm /tmp/reg1-${i}.fifo /tmp/reg2-${i}.fifo
  )&
  echo ${i} >&3
  echo ${i} >&4
done
exec 3>&-
exec 4>&-
rm /tmp/reg1.fifo /tmp/reg2.fifo
)&

xargs -n1 -I{} bash -c "docker_push reg1/{} 5; echo > /tmp/reg1-{}.fifo" < /tmp/reg1.fifo &
xargs -n1 -I{} bash -c "docker_push reg2/{} 1; echo > /tmp/reg2-{}.fifo" < /tmp/reg2.fifo &
wait
```

Такий паттерн можливо (не завжди треба, але можливо) також використовувати в мовах де є канали

{% foldable(title="Код на go. Cтворений для ілюстрації") %}

 
```go
package main

import (
	"log"
	"math/rand"
	"sync"
	"time"
)

type wait struct {
	image string
	done  chan<- struct{}
}

func main() {
	group := sync.WaitGroup{}
	ch1 := make(chan wait, 100)
	ch2 := make(chan wait, 100)
	images := []string{"image1", "image2", "image3", "image4", "image5"}

	group.Add(1)
	go func() {
		defer group.Done()
		for _, i := range images {
			// random sleep
			wait1 := make(chan struct{})
			wait2 := make(chan struct{})
			log.Printf("Start docker build %s", i)
			time.Sleep(time.Duration(rand.Intn(1000)) * time.Millisecond)
			log.Printf("Sending %s to channels", i)
			group.Add(1)
			go func() {
				defer group.Done()
				webhook_wg := sync.WaitGroup{}
				webhook_wg.Add(2)
				go func() {
					defer webhook_wg.Done()
					<-wait1
				}()
				go func() {
					defer webhook_wg.Done()
					<-wait2
				}()
				webhook_wg.Wait()
				log.Printf("Start webhook %s", i)
			}()
			ch1 <- wait{i, wait1}
			ch2 <- wait{i, wait2}
		}
		close(ch1)
		close(ch2)
	}()
	group.Add(2)
	go func() {
		defer group.Done()
		for i := range ch1 {
			log.Printf("Processing first repo %s", i.image)
			time.Sleep(time.Duration(rand.Intn(500)) * time.Millisecond)
			log.Printf("Processed %s in first repo", i.image)
			close(i.done)
		}
	}()
	go func() {
		defer group.Done()
		for i := range ch2 {
			log.Printf("Processing second repo %s", i.image)
			time.Sleep(time.Duration(rand.Intn(3200)) * time.Millisecond)
			log.Printf("Processed %s in second repo", i.image)
			close(i.done)
		}
	}()
	group.Wait()
}
```

{% end %}

І під кінець опитування - було б вам цікаво побачити більше постів про адвансед баш? Лишайте відповіді у коментарях. 

{{ tg(id="UkropsDigest/659")}}