import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:esense_flutter/esense.dart';
import 'dart:math';
import 'package:flutter_blue/flutter_blue.dart';


///
/// Entry Point of the Program
///
void main() => runApp(MainApp());

///
/// Parent Widget to the entire App
///
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

///
/// State of the Parent Widget
///
class _MyAppState extends State<MyApp> {
  String _deviceName = 'Unknown';
  double _voltage = -1;
  String _deviceStatus = '';
  bool sampling = false;
  String _event = '';
  DateTime lastImageUpdate = new DateTime(2000);
  int changedPicture = 0;
  // the name of the eSense device to connect to -- change this to your own device.
  String eSenseName = 'eSense-0058';
  Image img;
  String _button = '';
  bool deviceConnected = false;
  bool playing = false;
  FlutterBlue flutterBlue = FlutterBlue.instance;


  ///
  // / Initializes the State of the app at the start
  ///
  @override
  void initState() {
    super.initState();
    img = Image.network('https://picsum.photos/300/300');
    _connectToESense();
  }

  ///
  /// Method which connects to the ESense Device and
  /// starts the process of listening to Events coming from the device
  Future<void> _connectToESense() async {
    bool con = false;
    

    // if you want to get the connection events when connecting, set up the listener BEFORE connecting...
    ESenseManager.connectionEvents.listen((event) {
      print('CONNECTION event: $event');

      // when we're connected to the eSense device, we can start listening to events from it
      if (event.type == ConnectionType.connected) {
        _listenToESenseEvents();
        deviceConnected = true;
      }

        setState(() {
          switch (event.type) {
            case ConnectionType.connected:
              _deviceStatus = 'connected';
              deviceConnected = true;
              break;
            case ConnectionType.unknown:
              _deviceStatus = 'unknown';
              deviceConnected = false;
              break;
            case ConnectionType.disconnected:
              _deviceStatus = 'disconnected';
              deviceConnected = false;

              break;
            case ConnectionType.device_found:
              _deviceStatus = 'device_found';

              break;
            case ConnectionType.device_not_found:
              _deviceStatus = 'device_not_found';
              deviceConnected = false;

              break;
          }
        });

    });

    con = await ESenseManager.connect(eSenseName);

    setState(() {
      print(con);
      _deviceStatus = con ? 'connecting' : 'connection failed';

      print(con);
    });
  }



  ///
  /// This method reads out all events from the connected ESense device
  ///
  void _listenToESenseEvents() async {
    ESenseManager.eSenseEvents.listen((event) {
      print('ESENSE event: $event');

      setState(() {
        switch (event.runtimeType) {
          case DeviceNameRead:
            _deviceName = (event as DeviceNameRead).deviceName;
            break;
          case BatteryRead:
            _voltage = (event as BatteryRead).voltage;
            break;
          case ButtonEventChanged:
            _button = (event as ButtonEventChanged).pressed
                ? 'pressed'
                : 'not pressed';
            break;
          case AccelerometerOffsetRead:
            // TODO

            break;
          case AdvertisementAndConnectionIntervalRead:
            // TODO
            break;
          case SensorConfigRead:
            // TODO

            break;
        }
      });
    });

    _getESenseProperties();
  }

  ///
  /// method reads out all the Properties from the Esense device
  ///
  void _getESenseProperties() async {
    // get the battery level every 10 secs
    Timer.periodic(Duration(seconds: 10),
        (timer) async => await ESenseManager.getBatteryVoltage());

    // wait 2, 3, 4, 5, ... secs before getting the name, offset, etc.
    // it seems like the eSense BTLE interface does NOT like to get called
    // several times in a row -- hence, delays are added in the following calls
    Timer(
        Duration(seconds: 2), () async => await ESenseManager.getDeviceName());
    Timer(Duration(seconds: 3),
        () async => await ESenseManager.getAccelerometerOffset());
    Timer(
        Duration(seconds: 4),
        () async =>
            await ESenseManager.getAdvertisementAndConnectionInterval());
    Timer(Duration(seconds: 5),
        () async => await ESenseManager.getSensorConfig());
  }

  ///
  /// Updates the displyed image according to the direction the head was moved
  ///
  void updateImage(bool randomImage) {
    var rng = new Random();
    var url = randomImage
        ? 'https://picsum.photos/300/300?v=${rng.nextInt(100000)}'
        : 'https://cataas.com/cat?v=${rng.nextInt(100000)}';
    if (DateTime.now().difference(lastImageUpdate).inSeconds > 1) {
      lastImageUpdate = DateTime.now();
      img = Image.network(
        url,
        fit: BoxFit.fill,
        loadingBuilder: (context, child, progress) {
          return progress == null ? child : LinearProgressIndicator();
        },
        height: 300,
        width: 300,
      );
      changedPicture += 1;
    }
  }

  StreamSubscription subscription;



  ///
  /// Method to continuously read the data from the ESense device
  /// Interprets the gyro data to find out in which direction the head was moving
  ///
  void _startListenToSensorEvents() async {
    // subscribe to sensor event from the eSense device
    subscription = ESenseManager.sensorEvents.listen((event) {
      print('SENSOR event: $event');
      setState(() {
        _event = event.toString();

        if (event.gyro[0].abs() < 5000 &&
            event.gyro[1] / event.gyro[2] < 1.3 &&
            event.gyro[1] / event.gyro[2] > 0.7 &&
            event.gyro[1] > 5000) {
          updateImage(true);
        }

        if (event.gyro[0].abs() > -5000 &&
            event.gyro[1] / event.gyro[2] < 1.3 &&
            event.gyro[1] / event.gyro[2] > 0.7 &&
            event.gyro[1] < -5000) {
          updateImage(false);
        }
      });
    });

    setState(() {
      sampling = true;
    });
  }

  ///
  /// pauses the continuously data reading
  ///
  void _pauseListenToSensorEvents() async {
    subscription.cancel();
    setState(() {
      sampling = false;
    });
  }
  ///
  /// disconnects the device
  ///
  void dispose() {
    _pauseListenToSensorEvents();
    ESenseManager.disconnect();
    super.dispose();
  }

  Widget bluetoothStatus() {
    return IconButton(
      icon: deviceConnected ?
      Icon(Icons.bluetooth_connected,
        color: Colors.white,)
          : Icon(Icons.bluetooth,
        color: Colors.white,),
      onPressed: () {
        showBluetoothConnection();
      },
    );
  }
  ///
  /// Builds the AppBar of the app
  Widget ownAppBar() {
    return AppBar(
      title: const Text('Florian Giner Iot App'),
      centerTitle: true,
      backgroundColor: Colors.blueGrey[900],
      actions: <Widget>[
        bluetoothStatus()
      ],
    );
  }

  ///
  /// Builds the Drawer of the app
  ///
  Widget ownDrawer() {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: <Widget>[
      DrawerHeader(
        child: Center(
          child: Text(
            'Developer Information',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
        ),
      ),
      ListTile(
        title: Text(_deviceStatus),
      ),
      ListTile(
        title: Text(_deviceName),
      ),
      ListTile(
        title: Text('Press to reconnect to ESense Device'),
        onTap: () => _connectToESense(),
        selected: true,
      ),
      ListTile(
        title: Text(_event),
      )
    ]));
  }

  ///
  /// Builds the body of the app,
  /// the body contains all the actual content of the app
  ///
  Widget ownColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
                height: 80,
                child: Text(
                  sampling?'Move your head up and down!' : 'Press play!',
                  style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
                )),
            ),
        GestureDetector(
          onPanUpdate: (details) {
            if (details.delta.dy < -20) {
              setState(() {
                updateImage(true);
              });
            } else if(details.delta.dy > 20) {
              setState(() {
                updateImage(false);
              });
            }
          },
          child: Container(
            height: 300,
            child:  Center(
              child: ClipRRect(
                borderRadius: new BorderRadius.circular(8.0),
                child: img,
              ),
            ),
          )
        ),
        IconButton(
          onPressed:(!ESenseManager.connected)
              ? null
              : (!sampling)
              ? _startListenToSensorEvents
              : _pauseListenToSensorEvents,
          icon: (!sampling) ? Icon(Icons.play_arrow) : Icon(Icons.pause),
          iconSize: 80,
          color: Colors.blueGrey[900],
        ),
      ],

    );
  }

  ///
  /// Build the BottomBar of the app
  ///
  Widget ownBottomBar() {
    return BottomAppBar(
        color: Colors.blueGrey[900],
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Text(
            ' You have changed the picture $changedPicture times!',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ));
  }



  void showBluetoothConnection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: new Text('Connection status'),
          content: new Container(
            height: 400,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Container(
                  height: 300,
                  width: 300,
                  child: new ListView(
                    children: <Widget>[
                      new ListTile(
                        leading: new Text(deviceConnected? 'connected':'No connection'),
                      ),
                      new ListTile(
                        leading: Text(deviceConnected?_deviceName: 'No device connected'),

                      ),

                    ],
                  ),
                ),
                new Text('Help', style: TextStyle(fontWeight: FontWeight.bold),),
                new Text('Check if bluetooth is turned on.', textAlign: TextAlign.left, style: TextStyle(color: Colors.blueGrey),),
                new Text('Hold down the Button on both devices until they blink blue and red.', textAlign: TextAlign.left,style: TextStyle(color: Colors.blueGrey),),
                new Text('Press Connect.', textAlign: TextAlign.left,style: TextStyle(color: Colors.blueGrey),),
              ],
            ),
          ),
          elevation: 24.0,
          actions: <Widget>[
            new FlatButton(onPressed: () {
              if(deviceConnected) {
                Navigator.of(context).pop();
              } else {
                _connectToESense();
                Navigator.of(context).pop();
              }
            }, child: Text(deviceConnected? 'Close':'Connect'))
          ],
        );
      },
    );
  }


  void _showDialog() {
    // flutter defined function
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("ESense Device not found!"),
          content: new Text("Alert Dialog body"),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog

            new FlatButton(onPressed: ()
              {
                _connectToESense();
                Navigator.of(context).pop();

              }
        , child: new Text('Try again')),
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {Navigator.of(context).pop();
              },
            ),
          ],
          elevation: 24.0,
        );
      },
    );
  }



  ///
  /// Builds the app layout
  ///
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: ownAppBar(),
        body: ownColumn(),
        bottomNavigationBar: ownBottomBar(),

      );

  }
}

class MainApp extends StatelessWidget {
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
    return MaterialApp(
      title: 'Florian Giner Iot App',
      home: MyApp(),
    );
  }
}