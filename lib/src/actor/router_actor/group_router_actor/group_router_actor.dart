part of theater.actor;

/// This class is a base class for actors routers who create group of actorsduring initialization.
///
/// Group of actors may consists of the various type of [NodeActor].
abstract class GroupRouterActor extends RouterActor {
  /// Creates instanse of [GroupDeploymentStrategy] which the used for initialize [GroupRouterActor].
  @override
  GroupDeploymentStrategy createDeploymentStrategy();

  @override
  GroupRouterActorCellFactory _createActorCellFactory() => GroupRouterActorCellFactory();
}
