+++
title = "ChatGPT і DevOps"
date = "2023-05-10"
+++

Ні, цей допис не написало ChatGPT. Воно ще не вміє це робити на достатньому (для мене) рівні. 

Всі так бігають кругами навколо ChatGPT і генеративного AI, що прям тошно стає. GenerativeAI не якась магія, а звичайний додатковий інструмент. 

Так я думав.. Але після знайомства і використання на протязі кількох місяців я зробив для себе висновок — так, це інструмент. Але по рівню впливовості це як комп’ютер — теж **додатковий** інструмент, теж підвищує продуктивність. 

Тому я хочу вас заохотити погратися з GenerativeAI. 

Далі приведу деякі приклади з того що воно вміє робити і як зробити його корисним для девопсів. 

![is is working](/images/asd.jpg)


# З чого почати

* Зареєструйтеся на [openai](https://platform.openai.com)
* Увійдіть до [chatgpt](https://chat.openai.com)
* ...

# Нахолєру воно мені треба

За допомогою ChatGPT і [phind](https://phind.com) я:

* Створив багато різних **SQL** до клікхаусу і постгрі
* Створив сторінку з прикладами
* Створив дві лямбди для слака
* Дебажив github action, **k8s**, макось і тераформ код
* написав алпікацію для **macOS** 
* допилив *моніторінг* у графані
* створив багато **oneliners**
* перетворював дату з одного вигляду в інший
* наконфігурив різний софт (наприклад espanso)
* створив темплейт постмортему і безпековий темплейт
* писав *регулярки*

і це, блін, не все. Задача описати як можна використовувати GenerativeAI дуже складна. Це як описати навіщо тобі комп’ютер чи смартфон — в окремих випадках можливо, особливо якщо ти ~~дибіл~~ тільки в фіфу граєш. Але для *винахідливих* людей — фіг там. 

Мій висновок такий — продуктивність збільшилась в **декілька разів** і цю штуку треба використовувати усім, хто не хоче бути звільненим через два-три роки. 

# Що треба знати

Поперше, воно не розумне і *просто так* не буде вам допомогати. Типу як джун. 

І як і джуну, chatgpt потрібно давати чіткі інструкціі, щоб воно робило те що потрібно і не відволікалося і не тікало у лабіринти своєї підсвідомості. 

Тому від якості інструкцій залежить дуже багато. 

В якості прикладу я додам на цей сайт `foldable elements` (типу заниканий текст, по якому треба клікнути, щоб побачити)

Спочатку я напишу просто запит: 

{% foldable(title="GPT-4 bad prompt") %}

I'm using Zola static site generator, and I'd like to hide some long text under foldable elements. I'd like to use Zola shortcodes to achieve this. Please, create a code for me and show me where I should put this code. Also, I'd like it to be in same style wich other elements of my site 

> To create a foldable element using Zola shortcodes, you need to create a new shortcode file and then use it in your content. Follow these steps:
> 
> 1. Create a new file named `foldable.html` inside the `templates/shortcodes` directory in your Zola project. If the `shortcodes` directory doesn't exist, create it.
> 
> 2. Add the following code to the `foldable.html` file:
> 
> ```html
> {% set id = "foldable-" ~ uuid4() %}
> {% set title = title | default(value="Foldable title") %}
> 
> <div class="foldable-container" style="margin-bottom: 1rem;">
>   <input type="checkbox" id="{{ id }}" class="foldable-toggle" hidden />
>   <label for="{{ id }}" class="foldable-title" style="display: block; cursor: pointer; font-weight: bold; user-select: none;">
>     {{ title }}
>   </label>
>   <div class="foldable-content" style="display: none; margin-top: 0.5rem;">
>     {{ body }}
>   </div>
> </div>
> 
> <script>
>   document.getElementById("{{ id }}").addEventListener("change", function () {
>     let content = this.nextElementSibling.nextElementSibling;
>     content.style.display = this.checked ? "block" : "none";
>   });
> </script>
> ```
> 
> This code creates a foldable element with a title and hidden content. When the title is clicked, the content will be shown or hidden. The `id` is generated using a UUID to ensure it's unique on the page.
> 
> 3. Style the foldable element to match your site's design by modifying the inline `style` attributes or adding your own CSS classes to the elements.
> 
> 4. Use the `foldable` shortcode in your content files like this:
> 
> ```markdown
> {\{ foldable(title="My Foldable Title") }}
> Here is the long text that you want to hide under the foldable element.
> {{ /foldable }}
> ```
> 
> Replace "My Foldable Title" with your desired title and put your long text between the opening and closing `foldable` tags.
> 
> Now, when you build your site with Zola, the foldable elements will be generated, and you can click on the title to show or hide the hidden content.

{% end %}

І.. Ну воно щось зробило, але все в одному файлі, ще й не працює. І треба буде багато зусиль для того щоб воно закуревертелося. 

Натомість можна використати кращий промт:

{% foldable(title="GPT-4 better prompt") %}

You are a expert in Rust, CSS, HTMP and zola static site generator

You are conversing with another expert, so there is no need to elucidate fundamental engineering concepts.

I have a request and some existing data, and I need your assistance to accomplish it. 

To proceed, it is essential to follow these steps:

1. Determine my intention.
2. Familiarize yourself with the available data.
3. Ensure that you have comprehensive knowledge about the data.
4. Feel free to ask me any questions if my intentions are unclear.
5. Request examples of data and its storage location, if necessary, to accomplish your objective.
6. If required, repeat the previous steps.

Afterward, it would be helpful to provide me with suggestions on how to achieve my goals.

My request:

I'm using Zola static site generator, and I'd like to hide some long text under foldable elements. I'd like to use Zola shortcodes to achieve this. Please, create a code for me and show me where I should put this code. Also, I'd like it to be in same style wich other elements of my site 

> I understand that you want to create a foldable text element in Zola with the same style as the rest of your site. To help you best, could you please provide the following details?
> 
> 1. Can you share a sample of your site's existing style, perhaps a piece of your CSS or a description of your site's look and feel?
> 2. What is your preferred behavior for the foldable element? For example, should it unfold on click, hover, or some other action?
> 3. Would you like a single foldable element, or are you considering nested foldable elements?
> 
> Once I have this information, I'll be able to guide you more effectively.


{% end %}

Як ви можете бачити, воно вже питає, що саме я хочу і більш орієнтується на реальний світ. Тому, після того як я додав деталі і показав йому свій CSS, воно розбило усе по файлам і створило і код, і CSS, і у лобіка цьомнуло.  

## Приклади промптів

Взагалі, приклади не статичні, і я кожного дня щось поліпшую. Але як початкову точку ви можете використати промт який я зробив для інженерних задач (ви вже бачили його вище, якщо експандер працює😂)

{% foldable(title="example prompt") %}
You are a expert in DevOps, Linux and Google Cloud

You are conversing with another expert, so there is no need to elucidate fundamental engineering concepts.

I have a request and some existing data, and I need your assistance to accomplish it. 

To proceed, it is essential to follow these steps:

1. Determine my intention.
2. Familiarize yourself with the available data.
3. Ensure that you have comprehensive knowledge about the data.
4. Feel free to ask me any questions if my intentions are unclear.
5. Request examples of data and its storage location, if necessary, to accomplish your objective.
6. If required, repeat the previous steps.

Afterward, it would be helpful to provide me with suggestions on how to achieve my goals.

My request:

{% end %}

Проблема в тому, що сценаріїв використання якось багато. Тому поділюся хаком — усі ці *раніше безкорисні* експандери тексту сталі набагато кориснішими зараз. 

![expanders](/images/expanders.jpg)

Для прикладу, я використовую безкоштовний [espanso](https://espanso.org) з таким конфигом: 

{% foldable(title="Espanso match") %}
```yaml
matches:
  # Simple text replacement
  - trigger: ":expert"
    form: |
      You are a [[who]]

      You are conversing with another expert, so there is no need to elucidate fundamental engineering concepts.

      I have a request and some existing data, and I need your assistance to accomplish it. 
      
      To proceed, it is essential to follow these steps:
      
      1. Determine my intention.
      2. Familiarize yourself with the available data.
      3. Ensure that you have comprehensive knowledge about the data.
      4. Feel free to ask me any questions if my intentions are unclear.
      5. Request examples of data and its storage location, if necessary, to accomplish your objective.
      6. If required, repeat the previous steps.
      
      Afterward, it would be helpful to provide me with [[what]].
      
      My request:
      
    form_fields:
      who:
        type: list
        values: 
          - expert in DevOps, Linux and Google Cloud
          - expert in DevOps and terraform
          - expert in linux monitoring, statistics and machine learning
          - expert in Clickhouse database, data analysis and SQL
          - expert in product marketing
          - expert in project management and agile
      what:
        type: list
        values: 
          - suggestions on how to achieve my goals
          - resulting code with comments
          - example of code
```
{% end %}

Інший чудовий промтп який я використовую це:

```
I'd like to explain $|$ to a person. You using general knowledge, but you know nothing about current topic. Please, in each answer, provide me with your understanding of what I said. Also, analyze a tone of a message and show me examples of how I can make it friendly, casual, empathetic, and engaging. 

Template for your answers:

* I understand that you talked about: ...
* Your tone is: ...
* Possible improvements: ...
* termins that may need additional explanation: ...

Write 'Let's start' if you ready to start
```

І хопа, ChatGPT вже допомогає мені боротися з лаконічністю на грані божевілля. 

Взагалі пошукайте які є промти, модифікуйте і експерементуйте. Це дуже цікаво. 

# Покращення життя 

Крім [espanso](https://espanso.org) я дуже рекомендую усім хто на macOS поставити собі [macGPT](https://www.macgpt.com) 

Я перепробував майже усі альтернативи і це сподобалось найбільше. 

# Інші программи

[Rewind](https://www.rewind.ai) робить скріни вашого екрану кожні кілька секунд і розпізнає локально на макбуці. 
А потім можна в його запитати: "Чим я займався вчора" чи "Покажи усі PR що я ревьювив за останній тиждень" чи "я минулого місяця читав статтю про k8s де розповідали як вирішили проблему з мікросервісами і перейшли на моноліт, дай мені лінку на цю статтю"

Але дуже бісить що треба **постійно** виключати і включати, щоб сенсетів данні не пішли куди не треба. Тому я майже не використовую інтеграцію з openai, тоді усе локально. Але якщо в вас нема секретів, то рекомендую. 

[llamachat](https://llamachat.app), [llama.cpp](https://github.com/ggerganov/llama.cpp) і [dalai](https://github.com/cocktailpeanut/dalai) - рекомендую поставити усі три для запуска генеративних нейронок локально. Дуже корисно, особливо коли хочеться погратися з сенсетів данними і не відправляти їх на сервера openai.

[grammarly GO](https://www.grammarly.com/grammarlygo) - зручно для покращення тону повідомлень.
  
# Висновок

А його нема. 

Дуже хочеться щоб українська спільнота девопсів була *найкраща* і **найсучасніша**. Сподіваюсь так воно і буде 🇺🇦🇺🇦🇺🇦

{{ tg(id="UkropsDigest/589")}}
