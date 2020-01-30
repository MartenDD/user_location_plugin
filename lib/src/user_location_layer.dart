import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:user_location/src/user_location_options.dart';
import 'package:latlong/latlong.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'dart:math' as math;

class MapsPluginLayer extends StatefulWidget {
  final UserLocationOptions options;
  final MapState map;
  final Stream<Null> stream;

  MapsPluginLayer(this.options, this.map, this.stream);

  @override
  _MapsPluginLayerState createState() => _MapsPluginLayerState();
}

class _MapsPluginLayerState extends State<MapsPluginLayer>
    with TickerProviderStateMixin {
  LatLng _currentLocation;
  Marker _locationMarker;
  EventChannel _stream = EventChannel('locationStatusStream');
  var location = Location();

  bool mapLoaded;
  bool initialStateOfupdateMapLocationOnPositionChange;

  double _direction;


  StreamSubscription<LocationData> _onLocationChangedStreamSubscription;


  @override
  void initState() {
    super.initState();
    
    initialStateOfupdateMapLocationOnPositionChange =
        widget.options.updateMapLocationOnPositionChange;

    FlutterCompass.events.listen((double direction) {
      setState(() {
        _direction = direction;
      });
    });

    setState(() {
      mapLoaded = false;
    });
    initialize();
  }

  @override
  void dispose() {
    super.dispose();
    _onLocationChangedStreamSubscription.cancel();
  }

  void initialize() {
    location.hasPermission().then((onValue) async {
      if (onValue == false) {
        await location.requestPermission();
        printLog("Request Permission Granted");
        location.serviceEnabled().then((onValue) async {
          if (onValue == false) {
            await location.requestService();
            _handleLocationChanges();
            _subscribeToLocationChanges();
          } else {
            _handleLocationChanges();
            _subscribeToLocationChanges();
          }
        });
      } else {
        location.serviceEnabled().then((onValue) async {
          if (onValue == false) {
            await location.requestService();
            _handleLocationChanges();
            _subscribeToLocationChanges();
          } else {
            _handleLocationChanges();
            _subscribeToLocationChanges();
          }
        });
      }
    });
  }

  void printLog(String log) {
    if (widget.options.verbose) {
      print(log);
    }
  }

  Future<void> _subscribeToLocationChanges() async {
    printLog("OnSubscribe to location change");
    var location = Location();
    if (await location.requestService()) {
      _onLocationChangedStreamSubscription =
          location.onLocationChanged().listen((onValue) {
        _addsMarkerLocationToMarkerLocationStream(onValue);
        setState(() {
          if (onValue.latitude == null || onValue.longitude == null) {
            _currentLocation = LatLng(0, 0);
          } else {
            _currentLocation = LatLng(onValue.latitude, onValue.longitude);
          }

          var height = 20.0 * (1 - (onValue.accuracy / 100));
          var width = 20.0 * (1 - (onValue.accuracy / 100));
          if (height < 0 || width < 0) {
            height = 20;
            width = 20;
          }

          if (_locationMarker != null) {
            widget.options.markers.remove(_locationMarker);
          }
          //widget.options.markers.clear();

          _locationMarker = Marker(
              point:
                  LatLng(_currentLocation.latitude, _currentLocation.longitude),
              builder: (context) {
                return Stack(
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    Container(
                      alignment: Alignment.center,
                      color: Colors.white,
                      child: new Transform.rotate(
                        angle: ((_direction ?? 0) * (math.pi / 180) * -1),
                        child: CustomPaint(
                          size: Size(200, 100),
                          painter: MyDirectionPainter(),
                        )),
                    ),
                    Container(
                      height: height,
                      width: width,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue[300].withOpacity(0.7)),
                    ),
                    widget.options.markerWidget ??
                        Container(
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: Colors.blueAccent),
                        )
                  ],
                );
              });

          widget.options.markers.add(_locationMarker);

          if (widget.options.updateMapLocationOnPositionChange &&
              widget.options.mapController != null) {
            _moveMapToCurrentLocation();
          } else if (widget.options.updateMapLocationOnPositionChange) {
            if (!widget.options.updateMapLocationOnPositionChange) {
              widget.map.fitBounds(widget.map.bounds, FitBoundsOptions());
            }
            printLog(
                "Warning: updateMapLocationOnPositionChange set to true, but no mapController provided: can't move map");
          }

          if (widget.options.zoomToCurrentLocationOnLoad && (!mapLoaded)) {
            setState(() {
              mapLoaded = true;
            });
            animatedMapMove(
                _currentLocation, 17, widget.options.mapController, this);
          }
        });
      });
    }
  }

  void _moveMapToCurrentLocation({double zoom}) {
    animatedMapMove(
        LatLng(_currentLocation.latitude ?? LatLng(0, 0),
            _currentLocation.longitude ?? LatLng(0, 0)),
        zoom ?? widget.map.zoom ?? 15,
        widget.options.mapController,
        this);
    // widget.options.mapController.move(
    //     LatLng(_currentLocation.latitude ?? LatLng(0, 0),
    //         _currentLocation.longitude ?? LatLng(0, 0)),
    //     widget.map.zoom ?? 15);
  }

  void _handleLocationChanges() {
    printLog(_stream.toString());
    bool _locationStatusChanged;
    if (_locationStatusChanged == null) {
      _stream.receiveBroadcastStream().listen((onData) {
        _locationStatusChanged = onData;
        printLog("LOCATION ACCESS CHANGED: CURRENT-> ${onData ? 'On' : 'Off'}");
        if (onData == false) {
          var location = Location();
          location.requestService();
        }
        if (onData == true) {
          _subscribeToLocationChanges();
        }
      });
    }
  }

  _addsMarkerLocationToMarkerLocationStream(LocationData onValue) {
    if (widget.options.onLocationUpdate == null) {
      printLog("Strem not provided");
    } else {
      widget.options
          .onLocationUpdate(LatLng(onValue.latitude, onValue.longitude));
    }
  }

  Widget build(BuildContext context) {
    return widget.options.showMoveToCurrentLocationFloatingActionButton
        ? Positioned(
            bottom: widget.options.fabBottom,
            right: widget.options.fabRight,
            height: widget.options.fabHeight,
            width: widget.options.fabWidth,
            child: InkWell(
                hoverColor: Colors.blueAccent[200],
                onTap: () {
                  initialize();
                  if (initialStateOfupdateMapLocationOnPositionChange) {
                    setState(() {
                      widget.options.updateMapLocationOnPositionChange = false;
                    });
                  }
                  _moveMapToCurrentLocation(zoom: 17.0);
                },
                child: widget.options
                            .moveToCurrentLocationFloatingActionButton ==
                        null
                    ? Container(
                        decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: [
                              BoxShadow(color: Colors.grey, blurRadius: 10.0)
                            ]),
                        child: Icon(
                          Icons.my_location,
                          color: Colors.white,
                        ),
                      )
                    : widget.options.moveToCurrentLocationFloatingActionButton),
          )
        : Container();
  }

  void animatedMapMove(
      LatLng destLocation, double destZoom, _mapController, vsync) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _latTween = Tween<double>(
        begin: _mapController.center.latitude, end: destLocation.latitude);
    final _lngTween = Tween<double>(
        begin: _mapController.center.longitude, end: destLocation.longitude);
    final _zoomTween = Tween<double>(begin: _mapController.zoom, end: destZoom);

    // Create a animation controller that has a duration and a TickerProvider.
    var controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: vsync);
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
          LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation)),
          _zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (initialStateOfupdateMapLocationOnPositionChange) {
          setState(() {
            widget.options.updateMapLocationOnPositionChange = true;
          });
        }

        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        if (initialStateOfupdateMapLocationOnPositionChange) {
          setState(() {
            widget.options.updateMapLocationOnPositionChange = true;
          });
        }
        controller.dispose();
      }
    });
    controller.forward();
  }
}

class MyDirectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    final paint = Paint();
    // set the paint color to be white
    paint.color = Colors.white;
    // Create a rectangle with size and width same as the canvas
    var rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // draw the rectangle using the paint
    canvas.drawRect(rect, paint);
    paint.color = Colors.yellow;
    // create a path

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return false;
  }
}
