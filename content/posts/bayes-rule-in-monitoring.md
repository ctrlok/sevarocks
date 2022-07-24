+++
title = "Теорема Байеса, вероятности и мониторинг"
date = "2021-08-25"
+++

Так как возникли вопросы по применению — я написал небольшой пост. Уже 2 часа ночи и я могу где-то тупить, поэтому поправьте если где-то ошибся:   Про цифры ниже и оценки вероятностей событий можно спорить, но я попробую обьяснить на простом примере. 

# Пример

У нас раз в месяц случается какая-то херня. Каждый день мы запускаем проверку системы чтобы понять всё ли впорядке. 

То есть вероятность что херня случится именно сегодня — 1 к 30, то есть примерно 3% назовем это P(A)

Когда случается какая-то херня — cpu на серверах бывает то повышенным, то не повышенным в каждом втором случае. 
То есть вероятность того что случилась херня, я зайду на дашборд и увижу повышенный cpu - примерно 50% - назовем это P(B|A)

Но cpu бывает повышенный и сам по себе. Мы посмотрели как часто это случается за месяц и увидели что каждая пятая проверка показывает что cpu повышен — то есть 20% — назовем это P(B)

Если мы просто поставим алерт на cpu, то у нас будет очень false positive - то есть мы будем искать ошибку тогда, когда её нет.  Это ведёт к замыленности глаза и игнорированию. 

Чтобы понять какая вероятность того что случилась херня если cpu повышен нам надо: 

умножить между собой P(B|A) - вероятность того что мы увидим повышенный cpu когда случилась херня и P(A) - вероятность херни и разделить это всё на P(B) - вероятность того что мы увидим что cpu повышен

0.5 * 0.03 / 0.2 = 0.075, то есть примерно 7% вероятность что случилась херня 

# Почему?

Почему важно использовать эту формулу? Ну в случае с каждым вторым наблюдением повышенного cpu при херне может быть не понятно, но давайте повысим ставки. 

Например, у нас почти всегда повышен cpu когда случается какая-то херня - P(B|A) будет 90% - то есть в 9 из 10 случаев когда случается какая-то херня, я захожу в графану и вижу повышенный cpu

Многие эффективные менеджеры скажут — ну давай алертить каждый раз когда повышается CPU

но на самом деле, если каждая пятая проверка показывает повышенный CPU, то вероятность что именно сейчас происходят проблемы будет равняться 

0.9 * 0.03 / 0.2 = 13%

То есть почти 9 из 10 раз когда будет приходить такое сообщение в чат или кого-то будет будить это всё окажется зря. 

В итоге дежурные просто адоптируются и будут считать что эта метрика не говорит ничего полезного. Потому что в 9 из 10 случаев это просто шум. 

А вот если cpu повышен очень редко, например три проверок из ста показывают повышенный cpu, то есть смысл ставить на него алерт

Потому что вероятность херни будет 90%

0.9 * 0.03 / 0.03 = 90% 

# Применяем вероятности к SLA

А давайте возьмем компанию с SLO 99.99% — это значит что P(A) — вероятность херни примерно 0.01%

Если в 9 случаях из 10 cpu повышен когда случается херня 
И в 3 из ста случаях повышен когда мы делаем проверку, не взирая есть ли проблемы или нет, то

вероятность того что есть проблемы когда cpu повышен:

0.9 * 0.0001 / 0.03 = 0,0003, то есть 0.03%  То есть алерт на эту метрику ставить просто вообще никогда нельзя, потому что только на 3к сообщений одно будет полезным. 

Но всё веселье начинается когда у нас несколько событий: 

Например, новый пример. 

# Связанные события

Мы делаем чеки раз в 10 секунд

Система работает с SLO 99% годами. То есть только 0.1% времени не работает

У нас есть такие показатели: 

Система упала P(A) = 0.01

в 5 из 10 случаев система падала в течении часа после деплоя: P(B|A) = 0.5

в 9 из 10 случаев был повышен CPU: P(C|A) = 0.9

в 3 из 10 случаев в очереди были необработанные сообщения: P(D|A) = 0.3

Мы посмотрели на метрики и знаем что деплой у нас раз в день, то есть вероятность наступления события час после деплоя 1/24
То есть каждая 24-я проверка будет нам говорить что деплой произошел час назад - примерно 4% вероятность: P(B) = 0.04

CPU нам показывает повышенным каждая 5-я проверка, то есть вероятность того что cpu будет повышен при каждой проверке 20%: P(C) = 0.2

А каждая сотая проверка очереди нам говорит что там что-то есть: P(D) = 0.01

То есть у нас есть: 

P(A|B) = 0,125
P(A|C) = 0,045
P(A|D) = 0,075

И мы можем смело утверждать что нам не нужно отдельный алерт после каждой такой проверки. 

А вот какая вероятность что что-то сломалось если нам одновременно пришли три этих алерта? То есть P(A|BCD)
Для этого надо посчитать вероятность наступления всех трёх несвязанных событий P(BCD)

P(BCD) = P(B) * P(C) * P(D) = 0,00008, то есть примерно одна проверка из 80 000 будет показывать что все эти три события наступили одновременно. Вообще это выглядит как достаточно редкое событие.

P(A|BDC) = P(A) * P(BCD|A) / P(BCD) 
где P(BCD|A) - количество того когда все три события наблюдались одновременно когда случалась херня разделенное на количество херни которая случалась. 

А ещё хорошо бы прогнать по историческим данным и посмотреть, как часто такое событие P(BCD) случалось. Если значительно чаще чем раз в 80 000 проверок, значит эти события связаны и его надо расценивать не как независимые события, а как одно событие. 

Например, деплой может быть связан с тем что появляются сообщения в очереди. Тогда вместо того чтобы рассматривать наступление трех независимых событий, мы можем рассматривать деплой с сообщениями в очереди как одно конкретное событие и применять баесовскую формулу к нему. 
 В моей практике лучше всего работают связки двух зависимых и одного-двух независимых событий. Впрочем, даже с независимыми событиями получается прикольно. 

# Пример с короновирусом

Например, я сделал прививку и начал сильно боятся что вдруг я умру и сам себе сделал прививку из-за которой умру ведь есть случаи когда люди умирали (не смейтесь, это валидный аргумент, я его с знакомыми прорабатывал) 

Получается у меня есть два события

Смерть от проблем с сердцем в течении следующий 30 дней 
Сделанная прививка

Вероятность того что люди делают прививку P(A) = 60%

Вероятность смерти от проблем с сердцем в следующие 30 дней — я хз, но это будет P(B)

Количество смертей от проблем с сердцем в течении 30 дней после прививки - 13 человек из миллиона (B|A) = 0,0000128


То есть вероятность P(A|B) — что если я умру от проблем с сердцем в следующие 30 дней это будет из-за прививки:
0,0000128 * 0.6/ P(B) 

И это почти всегда будет крайне незначительное число. Впрочем, оно может увеличиваться если P(B) уменьшается. 

То есть, если вы находитесь в группе "молодые и здоровые без проблем и жировых отложений", то вероятность того что если вы умрете после прививки то это будет из-за прививки — очень сильно растёт. Впрочем, в всех остальных случаях вы скорее умрете просто от каких-то проблем со здоровьем хаха

{{ tg(id="devops_tricks/157")}}