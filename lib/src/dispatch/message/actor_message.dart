part of theater.dispatch;

abstract class ActorMessage {
  final dynamic data;

  final SendPort feedbackPort;

  ActorMessage(this.data, this.feedbackPort);

  void successful() {
    feedbackPort.send(DeliveredSuccessfullyResult());
  }

  void notFound() {
    feedbackPort.send(RecipientNotFoundResult());
  }

  void sendResult(dynamic result) {
    feedbackPort.send(MessageResult(data: result));
  }
}