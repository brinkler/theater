<div align="center" width="200px">

![](https://github.com/GlebBatykov/theater/blob/main/logo.png?raw=true)
  
Реализация модели акторов в Dart
  
</div>

<div align="center">

**Языки:**
  
[![English](https://img.shields.io/badge/Language-English-blue?style=?style=flat-square)](README.md)
[![Russian](https://img.shields.io/badge/Language-Russian-blue?style=?style=flat-square)](README.ru.md)
  
</div>  

- [Введение](#введение)
- [Про Theater](#про-theater)
- [Установка](#установка)
- [Что такое актор](#что-такое-актор)
  - [Примечания об акторах](#примечания-об-акторах)
  - [Применение акторов](#применение-акторов)
- [Система акторов](#система-акторов)
  - [Древо акторов](#древо-акторов)
- [Типы акторов](#типы-акторов)
- [Маршрутизация сообщений](#маршрутизация-сообщений)
  - [Адрес актора](#адрес-актора)
  - [Почтовые ящики](#почтовые-ящики)
    - [Ненадежный почтовый ящик](#ненадежный-почтовый-ящик)
    - [Надежный почтовый ящик](#надежный-почтовый-ящик)
    - [Приоритетный почтовый ящик](#приоритетный-почтовый-ящик)
  - [Посылка сообщений](#посылка-сообщений)
    - [Отправка по ссылке](#отправка-по-ссылке)
    - [Отправка без ссылки](#отправка-без-ссылки)
    - [Прием сообщений](#прием-сообщений)
    - [Получение ответа на сообщение](#получение-ответа-на-сообщение)
  - [Маршрутизаторы](#машрутизаторы)
    - [Маршрутизатор группы](#маршрутизатор-группы)
    - [Маршрутизатор пула](#маршрутизатор-пула)
- [Наблюдение и обработка ошибок](#наблюдение-и-обработка-ошибок)
- [Утилиты](#утилиты)
  - [Планировщик](#планировщик)
- [Дорожная карта](#дорожная-карта)

# Введение

Во время изучения Dart-а я задался вопросом - "Как я могу писать многопоточные программы на Dart-е?".

В Dart-е есть встроенный механизм позволяющий реализовывать многопоточное выполнение кода - изоляты.

Сами по себе изоляты в Dart-е неплохие. При помощи изолятов легко реализуются задачи по типу - отослать какую то входные данные в изолят, принять ответ от изолята после расчетов.

Изоляты в Dart-е являются вариацией реализации акторной модели (использование разделяемой памяти, общение при помощи посылки сообщений), однако они не имеют встроенных инструментов для простого создания множества изолятов общающихся между собой(необходимо постоянно передавать Send порты одних изолятов в другие, чтобы обеспечить возможность общения между ними), сценариев обработок ошибок, балансировщиков нагрузок.

При создании этого пакета я вдохновлялся Akka net и другими фреймворками с реализованной акторной моделью. Но я не ставил перед собой цель перенести Akka net в Dart, а лишь брал какие то моменты которые мне в нем нравились и переделывал под себя.

В данный момент пакет находится в стадии разработки, буду очень рад услышать чьи либо комментарии, идеи или сообщения об найденных проблемах.

# Про Theater

Theater - это пакет для упрощения работы с многопоточностью в Dart-е, для упрощения работы с изолятами.

Он предоставляет:
- систему маршрутизации сообщений между акторами (изолятами), которая инкапсулирует в себе работу с Receive и Send портами;
- систему обработки ошибок на уровне одного актора или группы акторов;
- возможности настройки маршрутизации сообщений (специальные акторы - маршрутизаторы, позволяющие устанавливать одну из предложенных стратегию маршрутизации сообщений между своими акторами-детьми, возможность задать приоритет сообщениям определенного типа);
- возможность балансировки нагрузки (сообщений) между акторами, создание пулов из акторов.

Сейчас в разработке находится возможность отправлять сообщение по сети в системы акторов находящиеся в других Dart VM.

# Установка

Добавьте Theater в ваш pubspec.yaml файл:

```dart
dependencies:
  theater: ^0.1.0
```

Импортируйте theater в файлы где он должен использоваться:

```dart
import 'package:theater/theater.dart';
```

# Что такое актор

Актор - это сущность которая имеет поведение и выполняется в отдельном изоляте. Имеет свой уникальный адрес (путь) в системе акторов. Он может принимать и отправлять сообщения другим акторам, пользуясь ссылками на них или используя лишь их адрес (путь) в системе акторов. Каждый актор имеет методы вызываемые в процессе его жизненного цикла (которые повторяют жизненный цикл его изолята):

- onStart(). Вызывается после того как актор стартует;
- onPause(). Вызывается перед тем как актор будет остановлен;
- onResume(). Вызывается после того как актор будет возобнавлен;
- onKill(). Вызывается перед тем как актор будет уничтожен.

У каждого актора есть почтовый ящик. Это то место куда попадают адресованные ему сообщения перед тем как попасть в актор. Об типах почтовых ящиков, можно прочитать [тут](#почтовые-ящики).

Акторы могут создавать акторов-детей. И выступать их руководителями (контролировать их жизненный цикл, обрабатывать ошибки возникающие в них). Жизненный цикл акторов-детей так же зависит от жизненного цикла их родетелей. 

## Примечания об акторах

При постановке актора на паузу, сначала ставятся на паузу все его акторы-дети.

Пример: есть 3 актора А1, А2, А3. А1 создал А2, А2 создал А3. Если А1 ставит на паузу А2 - А3 тоже будет поставлен на паузу. При этом сначала будет установлен на паузу А3, а затем А2.

При уничтожении актора, сначала уничтожаются все его дети. 

Пример: есть 3 актора А1, А2, А3. А1 создал А2, А2 создал А3. Если А1 уничтожает А2 - А3 тоже будет уничтожен. При этом сначала будет уничтожен А3, а затем А2.

## Применение акторов

Вы можете понять то как работают акторы по ходу прочтения этого README и происмотра примеров в README или [тут](https://github.com/GlebBatykov/theater/blob/main/example/README.ru.md).

Однако я думаю стоит упомянуть о том как предлагаю использовать акторов в Dart программах я.

Один актор должен инкапсулировать в себе одну конкретную задачу, если задачу можно разбить на подзадачи то в таком случае следует создать акторов-детей для актора реализующего большую задачу и повторять это до тех пор пока один актор не выполнял бы какую то одну определенную задачу.

Стоит учитывать что не во всех задачах использование акторов (изолятов) уместно. Перессылка сообщений между изолятами занимает некоторое время и использовать их стоит только тогда когда прирост в производительности от параллельных вычислений принесет перевешивает время потерянное на отправку сообщения.

В первую очередь этот подход позволил бы более эффективно использовать Dart на сервере (более легко и быстро реализуя многопоточную обработку запросов, строить более сложные схемы взаимодействия между изолятами), однако этот пакет можно использовать и в Flutter приложениях.

# Система акторов

Система акторов - это савокупность акторов, находящихся в иерархической структуре в виде древа. В пакете система акторов представлена классом [ActorSystem](). Перед работой с ней (созданием акторов, посылке сообщений и т.д) необходимо проинициализировать её. Во время инициализации система акторов создаст системных акторов, которые необходимы для её работы.

Акторы создаваемые при инициализации системы акторов:
- корневой актор. Уникальный актор создаваемый системой акторов при инициализации. Уникален он тем что не имеет родителя в виде другого актора, его родителем и тем кто контролирует его жизненный цикл является система акторов. При старте создает два актора, опекуна системы и опекуна пользователя;
- опекун системы. Актор являющийся прородителем всех системных акторов;
- опекун пользователя. Актор являющийся прородителем всех акторов верхнего уровня созданных пользователем.

Создание и инициализация системы акторов, создание тестового актора и вывод "Hello, world!" из него.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Print 'Hello, world!'
    print('Hello, world!');
  }
}

void main(List<String> arguments) async {
  // Create actor system with name 'test_system'
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'test_actor'
  await system.actorOf('test_actor', TestActor());
}
```

Созданный тестовый актор в примере выше будет иметь абсолютный путь к нему в системе акторов - "test_system/root/user/test_actor".

У ActorSystem есть методы приостанавливающие, возобновляющие, уничтожающие все акторы.

Метод dispose ActorSystem уничтожает все акторы, а так же закрывает все Stream-ы и освобождает все ресурсы используемые системой акторов, после вызова метода dispose дальнейшее использование того же экземпляра ActorSystem невозможно.

Если вы вызвали метод kill уничтожив все акторы в системе акторов, то чтобы продолжить работу с тем же экземплятром ActorSystem необходимо снова вызвать его метод initialize. Однако в таком случае все акторы верхнего уровня придется создавать заново.

## Древо акторов

В Theater система акторов представлена в виде иерархической структуры из акторов, эта структура называется древо акторов.

Вот то в каком виде древо акторов можно изобразить.

<div align="center">

![](https://i.ibb.co/qC98V4j/Actor-tree.png)
  
</div>
  
Акторы в древе делятся на 2 категории:
- руководителей (supervisor). Руководители это те акторы которые могут создавать своих акторов-детей (и сами в свою очередь имеют актора-руководителя);
- наблюдаемых (observable). Наблюдаемые акторы это те акторы которые не могут создавать акторов-детей.

Акторы-руководители контролируют жизненный цикл своих акторов-детей (уничтожают, останавливают, возобнавляют, запускают), они получают сообщения об ошибках происходящих в акторах-детях и принимают решения в соответствии с установленной стратегией (SupervisorStrategy). Подробнее об обработке ошибок в акторах-детях можно прочитать [тут](#наблюдение-и-обработка-ошибок).

Если переносить эти 2 категории на понятия более близкие к структуре древа, эти категории можно назвать так:
- руководитель это узел (node) древа;
- наблюдаемый актор это лист (sheet) древа.

Частный случай актора-узла это корневой актор. Это актор который имеет акторов-детей, но при этом не имеет актора-руководителя в виде другого актора. Его руководителем является сама система акторов.
  
# Типы акторов

В Theater пользователю представлены для использования следующие акторы:

- Untyped Actor. Универсальный актор, не имеющий особого назначения. Может принимать и отправлять сообщения другим акторам. Может создавать акторов-детей.
- Routers. Акторы маршрутизаторы, маршрутизирующие поступающие им запросы между их детьми в соответствии с установленной стратегией маршрутизации.
  - Pool Router Actor. Актор маршрутизатор, при старте создает пул однотипных WorkerActor-ов. Обращаться напрямую к его пулу Worker-ов нельзя, все запросы в пул поступают только через него. Может отсылать сообщения другим актора, все сообщения которые принимает маршрутизирует в свой пул акторов.
  - Group Router Actor. Актор маршрутизатор, при старте создает группу акторов-детей из указанных UntypedActor в его стратегии развертывания. Может отсылать сообщения другим акторам, но все сообщения что получает маршшрутизирует своим детям. Отличается от PoolRouterActor тем что к его детям можно отослать запроса напрямую, а не только через него.
- Worker Actor. Актор работник используемый в пуле акторов PoolRouterActor-а, похож на UntypedActor-а, однако не может создавать акторов-детей и имеет некоторые внутрение различия работы.

# Маршрутизация сообщений

## Адрес актора

Маршрутизация сообщений в Theater неотрывно связанна с понятием адреса актора, пути к нему. Следует уточнить что адрес актора является уникальным, то есть не может быть двух акторов с одинаковыми адресами.

Абсолютный путь к актору задается от названия системы акторов. В пути к актору так же помимо названия системы акторов, если речь идет об акторе созданном пользователем, указывается корневой актор (root) и опекун пользователя (user). 

Пример вывода абсолютного пути к созданному актору верхнего уровня.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    print(context.path);
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var actorSystem = ActorSystem('test_system');

  // Initialize actor system before work with her
  await actorSystem.initialize();

  // Create top-level actor in actor system with name 'test_actor'
  await actorSystem.actorOf('test_actor', TestActor());
}
```

Ожидаемый вывод

```dart
tcp://test_system/root/user/test_actor
```

В примере видно что полный путь к актору так же имеет в самом начале - "tcp". Что это означает? В данный момент в разработке находится возможность общения через сеть нескольких систем акторов находящихся в разных Dart VM. Приставка в начале пути к актору будет означать сетевой протокол используемый в этой системе акторов для общения с другими системами акторов по сети.

## Почтовые ящики

Почтовый ящик в Theater есть у каждого актора. Почтовый ящик это то место куда попадают запросы адресованные актору, прежде чем попасть в актор.

Почтовые ящики делятся на 2 типа:
- ненадежные;
- надежные.

### Ненадежный почтовый ящик

Ненадежные почтовые ящики это почтовые ящики без подтверждения доставки. Каждый актор по умолчанию имеет ненадежный почтовый ящик.

### Надежный почтовый ящик

Надеждый почтовый ящик это почтовый ящик с подтверждением доставки.

Подтверждение доставки означает что почтовый ящик после отправки сообщения актору дожидается от актора сообщения с подтвеждением факта доставки в него сообщения. Только после получения подтвеждения почтовый ящик отправляет в актор следующее сообщение.

Под получением сообщения актором подразумевается именно факт получения сообщение и запуска назначенных обработчиков для этого сообщения, но не факт выполнения всех назначенных ему обработчиков.

Это ухудшает производительность за за увеличения количества трафика, однако дает некоторые дополнительные гарантии того что актор получит отправленные ему сообщения. Из за увеличения трафика и траты времени на посылку дополнительных сообщений, ожиданий их получения - скорость отправки сообщений ухудшается более чем в 2 раза.

В каких ситуациях актор может не получить отправленные ему сообщения?

Если актор был в процессе работы уничтожен он не будет обрабатывать отправленые ему сообщения до тех пор пока снова не будет запущен и эти сообщения в это время будут находится в его почтовом ящике. 

Однако, кроме этого есть и другие внутренние средства на уровне каждого актора, которые в случае уничтожения актора позволяют не терять отправленные ему сообщения (они ожидают пока актор не будет снова запущен), использование почтового ящика с подтвержением является дополнительной мерой.
  
В действительности шанс утери сообщения иллюзорен и за время тестирования подобных случаев выявленно не было.

В целом использование почтовых ящиков с подтвеждением не обязательно, это ухудшает производительность, однако позволяет реализовывать приоритетные почтовые ящики.

### Приоритетный почтовый ящик

Это особый вид почтового ящика с подтверждением доставки в котором можно задать приоритет для сообщений. Приоритет определяет то в какой последовательности сообщения попадут в Event Loop актора (его изолята).

Приоритет задается при помощи класса PriorityGenerator.

Создание актора с приоритетным почтовым ящиком (в примере сообщения типа String имеют более высокий приоритет, чем сообщения типа int), отправка ему сообщений.

```dart
// Create actor class
class TestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });

    // Set handler to all int type messages which actor received
    context.receive<int>((message) async {
      print(message);
    });
  }

  // Override createMailboxFactory method
  @override
  MailboxFactory createMailboxFactory() => PriorityReliableMailboxFactory(
      priorityGenerator: TestPriorityGenerator());
}

// Create priority generator class
class TestPriorityGenerator extends PriorityGenerator {
  @override
  int generatePriority(object) {
    if (object is String) {
      return 1;
    } else {
      return 0;
    }
  }
}

void main(List<String> arguments) async {
  // Create actor system with name 'test_system'
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor' and get ref to it
  var ref = await system.actorOf('test_actor', TestActor());

  for (var i = 0; i < 5; i++) {
    ref.send(i < 3 ? i : i.toString()); // Send messages 0, 1, 2, "3", "4"
  }
}
```

В примере выше в актор было отправлено 5 сообщений - 0, 1, 2, "3", "4".

Ожидаемый вывод

```dart
0
3
4
1
2
```

В выводе можно заметить что все сообщения кроме первого получены актором в соответствии с их приоритетами. Происходит это из за того что первое сообщение при попадании в почтовый ящик было отправлено в актор до того как в почтовый ящик попали остальные сообщения и до того как приоритетная очередь в почтовом ящике была перестроена в соответствии с приоритетами сообщений.

Использование приоритетных почтовых ящиков как и почтовых ящиков с доставки не обязательно и ухудшает производительность, однако их комбинирование с ненадежными почтовыми ящиками позволяет добится баланса между производительностью, надежностью и удобством использования.

## Посылка сообщений

В Theater акторы могут отправлять сообщения друг другу по ссылкам к их почтовым ящикам. Ссылку можно получить при создании актора. Однако есть способ отправить сообщение другому актору и без ссылки на него используя его адрес, иначе было бы неудобно в условиях иерархической структуры отправлять сообщения по структуре вверх.

### Отправка по ссылке

Ссылка на актора инкапсулирует в себе SendPort для отправки сообщение в почтовый ящик актора.

Ссылку можно получить как при создании актора верхнего уровня при помощи системы акторов, так и при создании актора-ребенка через контекст актора.

В этом примеры мы при помощи системы акторов мы создаем актора верхнего уровня и получаем ссылку на его, отправляем ему сообщение.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  var ref = await system.actorOf('test_actor', TestActor());

  // Send 'Hello, from main!' message to actor
  ref.send('Hello, from main!');
}
```

В этом примере мы при помощи контекста UntypedActor-а создаем его актора-ребенка, получаем ссылку на него и отправляем ему сообщение.

```dart
class FirstTestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Create child with name 'second_test_actor'
    var ref = await context.actorOf('second_test_actor', SecondTestActor());

    // Send message
    ref.send('Luke, I am your father.');
  }
}

class SecondTestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      if (message == 'Luke, I am your father.') {
        print('Nooooooo!');
      }
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'first_test_actor'
  await system.actorOf('first_test_actor', FirstTestActor());
}
```

Таким образом можно отправлять сообщения в акторы по их ссылкам. Ссылки при желании можно передавать в другие акторы.

### Отправка без ссылки

В Theater вы можете отправлять сообщения акторам пользуясь ссылкой на актор, ссылку вы получаете когда создаете актор при помощи системы акторов или через контекст актора.

Однако использование ссылки может быть не всегда удобно, к примеру в случаях если актор будет отправлять сообщение акторам находящимся в древе акторов выше его.

Чтобы избежать подобных неудобств в Theater есть особый тип сообщений с указанием адресата. Когда актор получает на свой почтовый ящик сообщение такого типа он сверяет свой адрес и адрес указанный в сообщении. Если сообщение адресовано не ему он в зависмости от указанного адреса передает это сообщение вверх или вниз по древу акторов. 

Чтобы отправить такое сообщение нужно использовать метод send системы акторов или контекста актора. Есть 2 типа задаваемого адреса:
- абсолютный;
- относительный.

Абсолютный путь это полный путь к актору начиная от названия системы акторов, например - "test_system/root/user/test_actor".

Относительный путь это путь который задается относительно пути к текущему актору (при отправке сообщения через контекст актора) или относительно опекуна пользователя (в случае отправки сообщения через систему акторов). Пример относительного пути, если мы отправляем сообщение через систему акторов, при абсолютном пути к актору "test_system/root/user/test_actor" - "../test_actor".

Пример отправки сообщения актору используя систему акторов с указанием абсолютного пути.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  await system.actorOf('test_actor', TestActor());

  // Send message to actor using absolute path
  system.send('test_system/root/user/test_actor', 'Hello, from main!');
}
```

Пример отправки сообщения актору используя систему акторов с указанием относительного пути.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  await system.actorOf('test_actor', TestActor());

  // Send message to actor using relative path
  system.send('../test_actor', 'Hello, from main!');
}
```

Пример отправки сообщения актору находящемуся выше по иерархии актора, используя контекст актора с указанием абсолютного пути.

```dart
// Create first actor class
class FirstTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });

    // Create actor child with name 'test_child'
    await context.actorOf('test_child', SecondTestActor());
  }
}

// Create second actor class
class SecondTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Send message to parent using absolute path
    context.send('test_system/root/user/test_actor', 'Hello, from child!');
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  await system.actorOf('test_actor', FirstTestActor());
}
```

Пример отправки сообщения актору ребенку используя контекст актора с указанием относительного пути.

```dart
// Create first actor class
class FirstTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Create actor child with name 'test_child'
    await context.actorOf('test_child', SecondTestActor());

    // Send message to child using relative path
    context.send('../test_child', 'Hello, from parent!');
  }
}

// Create second actor class
class SecondTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  await system.actorOf('test_actor', FirstTestActor());
}
```

### Прием сообщений

Каждый актор может получать сообщение и обрабатывать их. Чтобы назначить актору обработчик на прием сообщение определенного типа вы можете воспользоваться методом receive в контексте актора. На сообщение одного типа можно назначать множество обработчиков.

Пример создания класса актора и при старте назначения обработчика приема сообщений типа String и int.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print(message);
    });
    
    // Set handler to all int type messages which actor received
    context.receive<int>((message) async {
      print(message);
    });
  }
}
```

### Получение ответа на сообщение

При отравке сообщений актору по ссылке или без ссылки может возникнуть потребность получить ответ на сообщение, это можно реализовать посылая в самом сообщении SendPort для ответа или заранее при создании актора передать некий SendPort в него. Или так же посылая сообщения без ссылки используя абсолютный или относительные пути вы можете неверно указать путь, это будет означать что сообщение не найдет своего адресата и желательно иметь возможность так же понимать когда такая ситуация возникает. В Theater есть механизм для этого - подписка на сообщение (MessageSubscription).

Посылая сообщение по ссылке или используя путь вы всегда используя метод send системы акторов или контекста актора получаете экземпляр MessageSubscription.

Используя метод onResponse можно назначить обработчик для получения ответа об состоянии сообщения.

Возможные состояния сообщений:
- DeliveredSuccessfullyResult - означает что сообщение успешно доставлено в актор, однако ответ он вам не отправил;
- RecipientNotFoundResult - означает что актора с таким адресом нет в древе акторов;
- MessageResult - означает что сообщение успешно доставлено, адресат отправил вам ответ на ваше сообщение.

Пример отправки сообщения в актор, получения ответа из него.  

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      // Print message
      print(message);

      // Send message result
      return MessageResult(data: 'Hello, from actor!');
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  var ref = await system.actorOf('actor', TestActor());

  // Send message 'Hello, from main!' to actor and get message subscription
  var subscription = ref.send('Hello, from main!');

  // Set onResponse handler
  subscription.onResponse((response) {
    if (response is MessageResult) {
      print(response.data);
    }
  });
}
```

Ожидаемый вывод

```dart
Hello, from main!
Hello, from actor!
```

Подписка на сообщение инкапсулирует в себе ReceivePort, обычная подписка на сообщение закрывает свой ReceivePort после получение одного результата на сообщение. 

Однако к примеру при использовании акторов маршрутизаторов может возникнуть необходимость принимать множество ответов из различных акторов на одно сообщение. Или если вы создали несколько обработчиков для сообщений одного типа и вы рассчитываете получить несколько ответов из обоих обработчиков.

Для этого вы можете превратить MessageSubscription в MultipleMessageSubscription используя метод asMultipleSubscription(). Такая подписка не закроет свой RecevePort после получения первого сообщения, однако это может создать не совсем прозрачную ситуацию из за использования внутри подписки ReceivePort-а, который вам необходимо будет уже закрыть самостоятельно используя метод cancel() подписки - тогда когда подписка станет вам не нужна.

## Машрутизаторы

В Theater существует особый вид акторов - маршрутизаторы.

Такие акторы имеют акторов детей создаваемых в соответствии с назначенной им стратегии развертывания. Переадресуют все сообщения адресованные им своим акторам-детям в соответствии с назначенной им стратегией маршрутизации сообщений. Основное назначение акторов данного типа это создание при помощи их балансировки сообщений между акторам.

В Theater существует 2 типа акторов-маршрутизаторов:
- маршрутизатор группы;
- маршрутизатор пула.

### Маршрутизатор группы

Маршрутизатор группы - это маршрутизатор который в качестве акторов-детей создает группу акторов-узлов (то есть акторами в этой группе могут выступать UntypedActor-ы или другие маршрутизаторы). В отличии от маршрутизатора пула позволяет присылать сообщения своим акторам-детям напрямую им, то есть не обязательно присылать им сообщения только лишь через маршрутизатор.

Имеет следующие стратегии маршрутизации сообщений:
- широковещательная (broadcast). Сообщение получаемое маршрутизатором пересылается всем акторам в его группе;
- случайная (random). Сообщение получаемое маршрутизатором пересылается случайному актору из его группы;
- по кругу (round robin). Сообщения получаемые маршрутизатором отправляется акторам из его группы по кругу. То есть если пришло 3 сообщения, а в группе акторов 2 актора, то 1 сообщение получит - актор №1, второе сообщение - актор №2, третье сообщение - актор №1.

Пример использования маршрутизатора группы с использованием широковещательной стратегии маршрутизации.

```dart
// Create first test actor class
class FirstTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Create router actor
    await context.actorOf('test_router', TestRouter());

    // Send message to router
    context.send('../test_router', 'Second hello!');

    // Send message to second without router
    context.send('../test_router/second_test_actor', 'First hello!');
  }
}

// Create router class
class TestRouter extends GroupRouterActor {
  // Override createDeployementStrategy method, configurate group router actor
  @override
  GroupDeployementStrategy createDeployementStrategy() {
    return GroupDeployementStrategy(
        routingStrategy: GroupRoutingStrategy.broadcast,
        group: [
          ActorInfo(name: 'second_test_actor', actor: SecondTestActor()),
          ActorInfo(name: 'third_test_actor', actor: ThirdTestActor())
        ]);
  }
}

// Create second test actor class
class SecondTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print('Second actor received message: ' + message);
    });
  }
}

// Create third test actor class
class ThirdTestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print('Third actor received message: ' + message);
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var actorSystem = ActorSystem('test_system');

  // Initialize actor system before work with her
  await actorSystem.initialize();

  // Create top-level actor in actor system with name 'hello_actor'
  await actorSystem.actorOf('first_test_actor', FirstTestActor());
}
```

Ожидаемый вывод

```dart
Second actor received message: Second hello!
Third actor received message: Second hello!
Second actor received message: First hello!
```

Структура древа акторов в системе акторов созданной в примере

<div align="center">

![](https://i.ibb.co/ZzHhr9q/group-router-example.png)

</div>
  
Из примера видно что мы создали актора с именем 'first_test_actor', который создал актор-маршрутизатор с именем 'test_router' содержащего в своей группе 2 актора, послал 2 сообщения. Первое сообщение было отправлено маршрутизатору (оно в последствии было отправлено всем акторам его группы), второе сообщение было отправлено только актору под именем 'second_test_actor'.

### Маршрутизатор пула

Маршрутизатор пула - это маршрутизатор который в качестве акторов-детей создает пул из однотипных назначенных ему акторов работников. В отличии от маршрутизатора группы не позволяет обращаться напрямую к акторам-работникам в своем пуле, то есть отправить в них сообщения можно только через маршрутизатор в соотстветствии с назначенной стратегией маршрутизации.

Что такое актор работник? Актор работник это особый вид актора используемый в маршрутизаторе пула. В целом тот актор похож на UntypedActor-а, но не может создавать акторов-детей, а так же имеет отличия во внутренней работе.

Отличия во внутрненней работе выражаются в том что актор работник после каждого обработанного сообщения, после того как он выполнит все назначенные для сообщения обработчики отсылает сообщение-отчет своему актору руководителю. Это создает дополнительный трафик при использовании маршрутизатора пула, однако позволяет использовать свойственную только ему стратегию маршрутизации позволяющую более эффективно балансировать нагрузку между акторами работниками в пуле.

Имеет следующие стратегии маршрутизации сообщений:
- широковещательная (broadcast). Сообщение получаемое маршрутизатором пересылается всем акторам в его группе;
- случайная (random). Сообщение получаемое маршрутизатором пересылается случайному актору из его группы;
- по кругу (round robin). Сообщения получаемые маршрутизатором отправляется акторам из его группы по кругу. То есть если пришло 3 сообщения, а в группе акторов 2 актора, то 1 сообщение получит - актор №1, второе сообщение - актор №2, третье сообщение - актор №1;
- балансировка нагрузки (balancing). Балансировка нагрузки между работниками в пуле с учетом того сколько еще не обработанных сообщений содержит каждый работник в пуле.

Пример создания маршрутизатора пула с использованием случайной стратегии маршрутизации.

```dart
// Create actor class
class TestActor extends UntypedActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Create router actor and get ref to him
    var ref = await context.actorOf('test_router', TestRouter());

    for (var i = 0; i < 5; i++) {
      // Send message to pool router
      ref.send('Hello message №' + i.toString());
    }
  }
}

// Create pool router class
class TestRouter extends PoolRouterActor {
  // Override createDeployementStrategy method, configurate group router actor
  @override
  PoolDeployementStrategy createDeployementStrategy() {
    return PoolDeployementStrategy(
        workerFactory: TestWorkerFactory(),
        routingStrategy: PoolRoutingStrategy.random,
        poolSize: 5);
  }
}

// Create actor worker class
class TestWorker extends WorkerActor {
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Set handler to all String type messages which actor received
    context.receive<String>((message) async {
      print('Received by the worker with path: ' +
          context.path.toString() +
          ', message: ' +
          message);
    });
  }
}

// Create worker factory class
class TestWorkerFactory extends WorkerActorFactory {
  @override
  WorkerActor create() => TestWorker();
}

void main(List<String> arguments) async {
  // Create actor system
  var actorSystem = ActorSystem('test_system');

  // Initialize actor system before work with her
  await actorSystem.initialize();

  // Create top-level actor in actor system with name 'test_actor'
  await actorSystem.actorOf('test_actor', TestActor());
}
```

Структура древа акторов в системе акторов созданной в примере

<div align="center">
  
![](https://i.ibb.co/nPNLyDk/pool-router-example.png)
  
</div>

Один из возможных результатов вывода

```dart
Received by the worker with path: tcp://test_system/root/user/test_actor/test_router/worker-1, message: Hello message №1
Received by the worker with path: tcp://test_system/root/user/test_actor/test_router/worker-2, message: Hello message №0
Received by the worker with path: tcp://test_system/root/user/test_actor/test_router/worker-4, message: Hello message №2
Received by the worker with path: tcp://test_system/root/user/test_actor/test_router/worker-2, message: Hello message №3
Received by the worker with path: tcp://test_system/root/user/test_actor/test_router/worker-1, message: Hello message №4
```

# Наблюдение и обработка ошибок

В Theater каждый актор, за исключением корневого, имеет актора-родителя управляющего его жизненным циклом и обрабатывающим исходящие из него ошибки, а так же каждый актор имеющий акторов-детей выступает управляющим актором для своих акторов-детей.

У каждого управляющего актора есть стратегия управления (SupervisorStrategy), которая обрабатывает принятую из актора-ребенка ошибку и в соответствии с исключением произошедшем в акторе-ребенке принимает указание (Directive) о том что необходимо сделать с ним.

Виды решений:
- возобновить (resume);
- перезапустить (restart);
- пауза (pause);
- уничтожить (kill);
- передать вышестоящему актору ошибку (escalate).

Стратегии делятся на 2 типа:
- один за один (OneForOne);
- один за всех (OneForAll).

Отличие этих двух стратегий в том что OneForOne стратегия применяет полученное указание к актору в котором произошла ошибка, а стратегия OneForAll применяет указание ко всем акторам-детям актора принимающего это решение. Стратегия OneForAll может пригодится в тех случаях когда у актора есть несколько детей работа которых очень тесно связанна друг с другом и ошибка в одном должна повлечь принятие решения применимое ко всем им.

По умолчанию каждый актор имеет OneForOne стратегию управления которая передает ошибку вышестоящиму актору. Когда ошибка доходит до опекуна пользователя он так же передает её наверх корневому актору, который в свою очередь передает ошибку системе акторов и система акторов уничтожает все акторы и генерирует исключение отображающее трасировку стека всех акторов через которых прошла ошибка.

Пример обработки ошибок с использование OneForOne стратегии

```dart
// Create first actor class
class FirstTestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Create child actor with name 'second_test_actor'
    await context.actorOf('second_test_actor', SecondTestActor());
  }

  // Override createSupervisorStrategy method, set decider and restartDelay
  @override
  SupervisorStrategy createSupervisorStrategy() => OneForOneStrategy(
      decider: TestDecider(), restartDuration: Duration(milliseconds: 500));
}

// Create decider class
class TestDecider extends Decider {
  @override
  Directive decide(Exception exception) {
    if (exception is FormatException) {
      return Directive.restart;
    } else {
      return Directive.escalate;
    }
  }
}

// Create second actor class
class SecondTestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    print('Hello, from second test actor!');

    // Someone random factor or something where restarting might come in handy
    if (Random().nextBool()) {
      throw FormatException();
    }
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'first_test_actor'
  await system.actorOf('first_test_actor', FirstTestActor());
}
```

В данном примере древо акторов и то что происходит в нем при возникновении ошибки можно представить так

<div align="center">

![](https://i.ibb.co/KwfMwwq/error-handling-example.png)

</div>

# Утилиты

## Планировщик

Планировщик это класс делающий более удобным создание некоторых задач которые должны повторятся спустя некое время. Каждый контекст актора имеет свой экземпляр планировщика, однако вы и сами можете создать свой экземпляр планировщика.

На самом деле в Dart-е задачи исполняющиеся периодически спустя некоторое время и так очень легко реализовать при помощи Timer, так что в Theater планировщик является лишь удобной абстракцией для этого. К примеру планировщик в Theater позволяет отменять несколько задач сразу при помощи токена отмены (CancellationToken).

В данный момент планировщик находится в стадии разработки и планируется добавить в него к примеру возможность передачи токенов отмены в другие акторы (в данный момент это невозможно), это позволит отменять запланировнные задачи из других акторов.

Пример создания задач при помощи планировщика, отмены запланировнных задач спустя 3 секунды при помощи токена отмены.

```dart
// Create actor class
class TestActor extends UntypedActor {
  // Override onStart method which will be executed at actor startup
  @override
  Future<void> onStart(UntypedActorContext context) async {
    // Create cancellation token
    var cancellationToken = CancellationToken();

    // Create first repeatedly action in scheduler
    context.scheduler.scheduleActionRepeatedly(
        interval: Duration(seconds: 1),
        action: () {
          print('Hello, from first action!');
        },
        cancellationToken: cancellationToken);

    // Create second repeatedly action in scheduler
    context.scheduler.scheduleActionRepeatedly(
        initDelay: Duration(seconds: 1),
        interval: Duration(milliseconds: 500),
        action: () {
          print('Hello, from second action!');
        },
        cancellationToken: cancellationToken);

    Future.delayed(Duration(seconds: 3), () {
      // Cancel actions after 3 seconds
      cancellationToken.cancel();
    });
  }
}

void main(List<String> arguments) async {
  // Create actor system
  var system = ActorSystem('test_system');

  // Initialize actor system before work with her
  await system.initialize();

  // Create top-level actor in actor system with name 'test_actor'
  await system.actorOf('test_actor', TestActor());
}
```

Ожидаемый вывод

```dart
Hello, from first action!
Hello, from second action!
Hello, from first action!
Hello, from second action!
Hello, from second action!
```

# Дорожная карта

Сейчас в разработке находятся:
- общение с системами акторов находящяхся в других Dart VM через сеть (udp, tcp);
- улучшение системы маршрутизации сообщений (больше функций и если необходимо то оптимизация);
- улучшение системы обработки ошибок, логирование ошибок.