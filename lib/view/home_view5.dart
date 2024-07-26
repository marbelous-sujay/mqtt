import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mqtt/model/message_model.dart';
import 'package:mqtt/utils/constants.dart';
import 'package:mqtt/utils/message_bubble.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_server_client.dart';
import 'package:uuid/uuid.dart';

class HomeView5 extends StatefulWidget {
  const HomeView5({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<HomeView5> createState() => _HomeView5State();
}

class _HomeView5State extends State<HomeView5> {
  bool isOnline = false;

  List<MessageModel> messages = [];
  TextEditingController messageTextController = TextEditingController();

  // String currentMessage = '';

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? clientUpdate;
  RxBool isConnected = false.obs;

  String getUUID() {
    return Uuid().v4();
  }

  @override
  void initState() {
    mqttConnect(
      brokerUrl: "ec2-3-110-172-173.ap-south-1.compute.amazonaws.com",
      port: 1883,
      username: "brainstem",
      password: "RBSXwdK%eBMN&#o6",
    );

    super.initState();
  }

  @override
  void dispose() {
    clientUpdate?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------------------
  // MQTT CONFIG -------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------

  late MqttServerClient client;

  void errorHandling({
    required Object error,
    required StackTrace stacktrace,
    bool displayError = false,
  }) {
    print("title: 'ERROR', content: $error");
    print("title: 'STACKTRACE', content: $stacktrace");

    if (displayError) {
      print('$error');
    }
  }

  // -------------------------------------------------------------------------------------
  // CONNECT MQTT ------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------

  Future<MqttServerClient> mqttConnect({
    required String brokerUrl,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      client = MqttServerClient.withPort(
        brokerUrl,
        '',
        port,
      );
      client
        ..logging(on: false)
        ..keepAlivePeriod = 15
        ..autoReconnect = true
        ..onConnected = onConnected
        ..onDisconnected = onDisconnected
        ..onAutoReconnect = onAutoReconnected
        ..pongCallback = pong
        ..onSubscribed = onSubscribed
        ..onSubscribeFail = onSubscribeFail
        ..onUnsubscribed = onUnsubscribed
        ..connectionMessage = MqttConnectMessage();

      print('MQTT content: CONNECTING');

      try {
        await client.connect(username, password);
      } catch (e, stacktrace) {
        print("Error while MQTT CONNECT");
        errorHandling(error: e, stacktrace: stacktrace);
      }

      if (checkIfConnected()) {
        print('MQTT  CONNECTED');
      } else {
        print(
          'MQTT   CONNECTION FAILED - disconnecting, status is ${client.connectionStatus}',
        );
        client.disconnect();
      }

      await clientUpdate?.cancel();

      clientUpdate = client.updates.listen((c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final payload =
            MqttUtilities.bytesToStringAsString(recMess.payload.message!);

        handleClientUpdate(topic: c[0].topic, payload: payload);
      });
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
      client.disconnect();
    }
    return client;
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [onConnected]
  // --------------------------------------------------------------------------

  void onConnected() {
    isConnected(true);
    setState(() {
      isOnline = true;
    });
    mqttSubscribeTopic(topic: mqttTopic);
    print(
      'MQTT  OnConnected client Callback - Client connection was successful',
    );
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [onDisconnected]
  // --------------------------------------------------------------------------

  void onDisconnected() {
    isConnected(false);
    setState(() {
      isOnline = false;
    });
    print('MQTT content: Disconnected');
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print(
        'MQTT OnDisconnected callback is solicited, this is correct',
      );
    } else {
      print(
        'MQTT OnDisconnected callback is unsolicited or none, this is incorrect - exiting',
      );
    }
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [onAutoReconnected]
  // --------------------------------------------------------------------------

  void onAutoReconnected() {
    print('MQTT   AutoReconnected');
    if (checkIfConnected()) {
      isConnected(true);
      setState(() {
        isOnline = true;
      });
      mqttSubscribeTopic(topic: mqttTopic);
    } else {
      isConnected(false);
      setState(() {
        isOnline = false;
      });
    }
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [pong]
  // --------------------------------------------------------------------------

  void pong() {
    print('MQTT   Ping response client callback invoked');
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [onSubscribed]
  // --------------------------------------------------------------------------

  void onSubscribed(MqttSubscription topic) {
    print('MQTT Subscribed topic --> $topic');
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [onSubscribeFail]
  // --------------------------------------------------------------------------

  void onSubscribeFail(MqttSubscription topic) {
    print('MQTT content SubscribeFail topic --> $topic');
  }

  // --------------------------------------------------------------------------
  // MQTT FUNC [onUnsubscribed]
  // --------------------------------------------------------------------------

  void onUnsubscribed(MqttSubscription topic) {
    print(
      'MQTT Subscription unsubscribed for topic $topic',
    );
  }

  // ----------------------------------------------------------------------
  // CHECK IF CONNECTED ----------------------------------
  // ----------------------------------------------------------------------

  bool checkIfConnected() {
    print(
        'client.connectionStatus?.state content: client.connectionStatus?.state,');
    isOnline = client.connectionStatus?.state == MqttConnectionState.connected;
    return client.connectionStatus?.state == MqttConnectionState.connected;
  }

  // ----------------------------------------------------------------------
  // MQTT Functions - SUBSCRIBE TO TOPIC ----------------------------------
  // ----------------------------------------------------------------------

  void mqttSubscribeTopic({required String topic}) {
    try {
      client.subscribe(topic, MqttQos.exactlyOnce);
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
    }
  }

  // ----------------------------------------------------------------------
  // MQTT Functions - UNSUBSCRIBE FROM TOPIC -----------------------------
  // ----------------------------------------------------------------------

  void mqttUnSubscribeTopic({required String topic}) {
    try {
      client.unsubscribeStringTopic(topic);
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
    }
  }

  // ----------------------------------------------------------------------
  // MQTT Functions - PUBLISH TO TOPIC -----------------------------
  // ----------------------------------------------------------------------

  void publishToTopic({required String topic, required String message}) {
    try {
      if (isConnected()) {
        print(
          'MQTT,   TOPIC : $topic, PAYLOAD : ${message}}',
        );

        final builder = MqttPayloadBuilder()..addString(message);
        client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        print('MQTT message PUBLISHED');
      }
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
    }
  }

  // ----------------------------------------------------------------------
  // MQTT Handle Response
  // ----------------------------------------------------------------------

  void handleClientUpdate({required String? topic, required String payload}) {
    print(
      'MQTT,   TOPIC : $topic, PAYLOAD : $payload',
    );

    final res = jsonDecode(payload);

    setState(() {
      messages.insert(0,
        MessageModel(
          message: res['message'],
          time: res['time'],
          senderId: res['senderId'],
        ),
      );
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent.shade100,
        title: Row(
          children: [
            Text(
              '● ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    !isOnline ? Colors.orangeAccent : Colors.lightGreenAccent,
              ),
            ),
            const SizedBox(width: 30),
            const Text('Messenger'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                shrinkWrap: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return MessageBubble(
                    message: messages[index].message,
                    isMe: messages[index].senderId == widget.id,
                    time: messages[index].time,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              child: TextFormField(
                controller: messageTextController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  suffixIcon: IconButton(
                    onPressed: () {
                      var payload = {
                        'senderId': widget.id,
                        'time': DateFormat('HH:mm:ss').format(DateTime.now()).toString(),
                        'message': messageTextController.text,
                      };

                      publishToTopic(
                        topic: mqttTopic,
                        message: jsonEncode(payload),
                      );

                      setState(() {
                        messageTextController.clear();
                      });
                    },
                    icon: const Icon(
                      Icons.send,
                      color: Colors.grey,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
