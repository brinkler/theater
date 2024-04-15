part of theater.actor;

class GroupRouterActorProperties extends RouterActorProperties {
  final GroupDeploymentStrategy DeploymentStrategy;

  GroupRouterActorProperties(
      {required this.DeploymentStrategy,
      required super.handlingType,
      required super.actorRef,
      required super.supervisorStrategy,
      required super.parentRef,
      required super.mailboxType,
      required super.actorSystemSendPort,
      required super.loggingProperties,
      Map<String, dynamic>? data})
      : super(data: data ?? {});
}
