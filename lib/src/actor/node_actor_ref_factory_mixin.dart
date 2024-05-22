part of theater.actor;

mixin NodeActorRefFactoryMixin<P extends SupervisorActorProperties>
    on SupervisorActorContext<P> implements ActorRefFactory<NodeActor> {
  @override
  Future<LocalActorRef> actorOf<T extends NodeActor>(String name, T actor,
      {Map<String, dynamic>? data, void Function()? onKill}) async {
    var actorPath = path.createChild(name);

    if (_children.map((e) => e.path).contains(actorPath)) {
      throw ActorContextException(
          message: 'actor contains child actor with name [$name]');
    }
    _childErrorSubscription.pause();

    var actorCellFactory = actor._createActorCellFactory();

    var actorCell = actorCellFactory.create(
        actorPath,
        actor,
        NodeActorCellProperties(
            actorSystemSendPort: _actorProperties.actorSystemSendPort,
            parentRef: _actorProperties.actorRef,
            loggingProperties: ActorLoggingProperties.fromLoggingProperties(
                _actorProperties.loggingProperties,
                actor.createLoggingPropeties()),
            data: data,
            onKill: onKill));

    actorCell.errors.listen((error) => _childErrorController.sink.add(error));

    _children.add(actorCell);

    await actorCell.initialize();

    await actorCell.start();

    _childErrorSubscription.resume();

    return actorCell.ref;
  }

  /// Checks if the register exist a reference to an actor with path - [path].
  ///
  /// You have two way how point out path to actor:
  ///
  /// - relative;
  /// - absolute.
  ///
  /// The relative path is set from current actor.
  ///
  /// For example current actor has the name "my_actor", you can point out this path "system/root/user/my_actor/my_child" like "../my_child".
  ///
  /// Absolute path given by the full path to the actor from the name of the system of actors.
  Future<bool> isExistLocalActorRef(String path) async {
    if (_children.map((e) => e.path.toString()).contains(path)) {
      return true;
    }

    var actorPath = _parsePath(path);

    var receivePort = ReceivePort();

    _actorProperties.actorSystemSendPort.send(
        ActorSystemIsExistUserLocalActorRef(actorPath, receivePort.sendPort));

    var result =
        await receivePort.first as ActorSystemIsExistLocalActorRefResult;

    receivePort.close();

    return result.isExist;
  }
}
