part of theater.actor;

class PoolRouterActorProperties extends RouterActorProperties {
  final PoolDeploymentStrategy DeploymentStrategy;

  PoolRouterActorProperties(
      {required this.DeploymentStrategy,
      required super.actorRef,
      required super.supervisorStrategy,
      required super.parentRef,
      required super.handlingType,
      required super.mailboxType,
      required super.actorSystemSendPort,
      required super.loggingProperties,
      Map<String, dynamic>? data})
      : super(data: data ?? {});
}
