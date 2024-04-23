part of theater.logging;

class TheaterLogger extends Logger {
  final String _template;

  late final List<LoggerMiddleware> _middlewares;

  TheaterLogger(String template, ActorPath path)
      : _template = template,
        super(path) {
    _middlewares = [
      TimeMiddleware(),
      DateMiddleware(),
      ActorNameMiddleware(),
      ActorPathMiddleware(),
      LogLevelMiddleware(),
      MessageMiddleware()
    ];
  }

  @override
  void info(dynamic object, {String? template}) {
    _log(object, template ?? _template, LogLevel.info);
  }

  @override
  void debug(dynamic object, {String? template}) {
    _log(object, template ?? _template, LogLevel.debug);
  }

  @override
  void warning(object, {String? template}) {
    _log(object, template ?? _template, LogLevel.warning);
  }

  @override
  void error(object, {String? template}) {
    _log(object, template ?? _template, LogLevel.error);
  }

  @override
  void critical(object, {String? template}) {
    _log(object, template ?? _template, LogLevel.critical);
  }

  void _log(dynamic object, String template, LogLevel level) {
    var log = Log(template, level, path, object.toString());

    for (var middleware in _middlewares) {
      log = middleware.handle(log);
    }

    print(log.template + '\n');
  }
}
