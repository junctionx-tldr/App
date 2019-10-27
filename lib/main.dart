import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'dart:ui' as ui;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:tldr/slider.dart';
import 'pathData.dart';

void main() => runApp(MyApp());

class Station {
  Station(this.latLng, this.serial, this.description);
  LatLng latLng;
  String serial;
  String description;

  @override
  String toString() {
    // TODO: implement toString
    return "[latLng]: " + latLng.toString() + "\t[serial]: " + serial;
  }
}

Future<Map<String, dynamic>> _makeGetRequest() async {
  // make GET request
  String url = 'https://api.hypr.cl/station';
  Map<String, String> req_headers = {
    "x-api-key": "iQ0WKQlv3a7VqVSKG6BlE9IQ88bUYQws6UZLRs1B",
    "command": "list",
    "Accept": "*/*",
    "Cache-Control": "no-cache",
    "Host": "api.hypr.cl",
    "Accept-Encoding": "gzip, deflate",
    "Content-Length": "0",
    "Connection": "keep-alive",
    "cache-control": "no-cache",
    "time_start": "2019-07-15T08:00:01Z",
    "time_stop": "2019-07-15T08:00:02Z"
  };
  Response response = await post(url, headers: req_headers);
  // sample info available in response
  int statusCode = response.statusCode;
  Map<String, String> headers = response.headers;
  String contentType = headers['content-type'];
  Map<String, dynamic> station = jsonDecode(response.body);
  return station;
  //return response.body.toString();
  // TODO convert json to object...
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Google Maps Demo',
      home: MapSample(),
    );
  }
}

class MapSample extends StatefulWidget {
  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
    static MapSampleState self;


  MapSampleState(){
    self=this;
  }
  Completer<GoogleMapController> _controller = Completer();
  List<Station> _result = new List<Station>();
  Map<MarkerId, Marker> stationMarkers =
      <MarkerId, Marker>{}; // CLASS MEMBER, MAP OF MARKS
  Timer _timer;

  BitmapDescriptor stationIcon;
  Set<Circle> circles = <Circle>{};

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }

  List<Polyline> polylines = [];
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  Map<String, List<LatLng>> vehicleLines = {};
  Map<int,dynamic> hourCache ={};
  bool isGetTrafficDataRunning = false;

  GetChildren(Map<String, dynamic> graph, Map<String, dynamic> parentGrapNode,
      int day) {
    String station;
    Station currentStation;
    Station lastStation;
    if (graph.containsKey("station") &&
        parentGrapNode != null &&
        parentGrapNode.containsKey("station")) {
      station = graph["station"];
      //print(graph);
      currentStation =
          _result.firstWhere((x) => x.serial == station, orElse: () => null);
      lastStation = _result.firstWhere(
          (x) => x.serial == parentGrapNode["station"],
          orElse: () => null);
      if (currentStation != null && lastStation != null) {
        var routBetWeenStations = Routes.RouteList.firstWhere(
            (x) =>
                x.startStation.serial == lastStation.serial &&
                x.endStation.serial == currentStation.serial,
            orElse: () => null);

        var parentWeight = parentGrapNode["weight"];
        var currentWeight = graph["weight"];
        var routeWeight = currentWeight / parentWeight;

        if (routBetWeenStations != null) {
          var polyline = Polyline(
              polylineId:
                  PolylineId(lastStation.serial + currentStation.serial),
              color: (day == 1 ? Colors.orangeAccent : Colors.green)
                  .withOpacity(routeWeight * 0.5),
              width: (10 * routeWeight).round(),
              points: routBetWeenStations.routeSegmentList);
          polylines.add(polyline);
        }
        else{
              print("NULL POLYLINES ");

        }
      }
    } else {
      station = "root";
    }

    if (graph.containsKey("children")) {
      List<dynamic> childrenGraph = graph["children"];
      for (int i = 0; i < childrenGraph.length; i++) {
        GetChildren(childrenGraph[i][1], graph, day);
      }
    }
  }

  static ChangeHour (int hour) {
    self.polylines.clear();
    if(self.hourCache.containsKey(hour)){
       self.GetChildren(self.hourCache[hour], null, 1);
    }
  }
  int currentMapId = 1;
  GetMovementGraph() async {
    //print("CURR MAP ID:"+currentMapId.toString());
    get("http://szabto.com/graph_" + currentMapId.toString() + ".json")
        .then((x) {
    //print("INNER CURR MAP ID:"+currentMapId.toString());

      Map<String, dynamic> graph_1 = jsonDecode(x.body);
      var graphChildren = graph_1["children"][0][1];
      hourCache[currentMapId]=graph_1;
      if (currentMapId == 1) {
        GetChildren(graphChildren, null, 1);
      }
      TimeSpanSliderState.bars
          .add(((graphChildren["weight"] /  1100)*50).round());
          currentMapId++;
      //print("STAYED: "+graphChildren["weight"].toString());
      if (currentMapId < 24) {
        GetMovementGraph();
      }
    });

    /* var response_2 = await get("http://szabto.com/graph_2.json");
    Map<String,dynamic> graph_2 = jsonDecode(response_2.body);
    GetChildren(graph_2["children"][0][1],null, 2);*/
  }

  GetMapStyle() async {
    var response = await get("http://szabto.com/gstyle.txt");
    return response.body;
  }

  GetTrafficData() async {
    if (this.isGetTrafficDataRunning) return;

    var response = await get("http://szabto.com:3000/get_vehicles");
    this.isGetTrafficDataRunning = true;
    Map<String, dynamic> data = jsonDecode(response.body);
    var values = data.values.toList();
    for (int i = 0; i < values.length; i++) {
      var latitude = values[i]["lat"];
      var longitude = values[i]["lon"];
      var id = values[i]["id"].toString();
      circles.add(Circle(
          fillColor: Colors.redAccent.withOpacity(0.6),
          circleId: CircleId(id.toString()),
          center: LatLng(latitude, longitude),
          strokeWidth: 4,
          strokeColor: Colors.redAccent,
          radius: 20));

      if (!vehicleLines.containsKey(id)) {
        vehicleLines[id] = new List<LatLng>();
      }

      if (vehicleLines[id].length > 5) {
        //vehicleLines[id].remo();
      }

      vehicleLines[id].add(LatLng(latitude, longitude));

      Polyline polyline = Polyline(
          polylineId: PolylineId("traffic_" + id.toString()),
          color: Colors.redAccent.withOpacity(0.5),
          width: 3,
          points: vehicleLines[id]);
      polylines.add(polyline);
    }

    isGetTrafficDataRunning = false;
  }

  void startTimer() {
    const oneSec = const Duration(milliseconds: 1000);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) => setState(
        () {
            GetTrafficData();
        },
      ),
    );
  }

  @override
  void initState() {
    Routes.init();
    startTimer();
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(size: Size(20, 20)), 'assets/station.png')
        .then((onValue) {
      setState(() {
        stationIcon = onValue;
      });
    });

    _makeGetRequest().then((result) {
      setState(() {
          GetMovementGraph();

        for (int i = 0; i < result['list'].length; i++) {
          var currentLatLon = new LatLng(
              result['list'][i]['latitude'], result['list'][i]['longitude']);
          var currentSerial = result['list'][i]['serial'].toString();
          // Create station objects
          _result.add(new Station(currentLatLon, currentSerial,
              result['list'][i]['description'].toString()));

          var markerId = MarkerId(currentSerial);

          _goToTheLake();
          // Add circles
          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.8),
              circleId: CircleId(currentSerial),
              center: currentLatLon,
              strokeWidth: 2,
              strokeColor: Colors.blue.withOpacity(0.8),
              radius: 8));
          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.5),
              circleId: CircleId(currentSerial + 'v2'),
              center: currentLatLon,
              strokeWidth: 10,
              strokeColor: Colors.blue.withOpacity(0.5),
              radius: 40));

          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.04),
              circleId: CircleId(currentSerial + 'v3'),
              center: currentLatLon,
              strokeWidth: 0,
              strokeColor: Colors.blue.withOpacity(0.04),
              radius: 1000));

          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.08),
              circleId: CircleId(currentSerial + 'v34'),
              center: currentLatLon,
              strokeWidth: 0,
              strokeColor: Colors.blue.withOpacity(0.08),
              radius: 600));

          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.1),
              circleId: CircleId(currentSerial + 'v4'),
              center: currentLatLon,
              strokeWidth: 0,
              strokeColor: Colors.blue.withOpacity(0.1),
              radius: 300));

          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.125),
              circleId: CircleId(currentSerial + 'v41'),
              center: currentLatLon,
              strokeWidth: 0,
              strokeColor: Colors.blue.withOpacity(0.125),
              radius: 200));

          circles.add(Circle(
              fillColor: Colors.blue.withOpacity(0.15),
              circleId: CircleId(currentSerial + 'v5'),
              center: currentLatLon,
              strokeWidth: 0,
              strokeColor: Colors.blue.withOpacity(0.15),
              radius: 150));

          LatLng getShape(LatLng latLng) {}
/*
for(int i=0;i<25;i++){
  
  polylines.add(new Polyline(
    color: Colors.blue.withOpacity(0.5),
    jointType: JointType.round,
    width: 2,
    polylineId: PolylineId(currentSerial + result['list'][i]['serial'].toString()),
    points: [currentLatLon, new LatLng( result['list'][i]['latitude'], result['list'][i]['longitude'])],
  ));
}*/

/*circles.add(
   Circle(
     fillColor: Colors.blue.withOpacity(0.2),
    circleId: CircleId(result['list'][i]['serial'].toString()),
    center: currentLatLon,
    strokeWidth: 10,
    strokeColor: Colors.blue.withOpacity(0.2),
    radius: 8)
);*/

          // Add markers for the stations
          var currentMarker = Marker(
            icon: stationIcon,
            markerId: markerId,
            position: currentLatLon,
            infoWindow: InfoWindow(
                title: result['list'][i]['description'], snippet: '*'),
            onTap: () {},
          );

          stationMarkers[markerId] = currentMarker;
        }
      });
      for (int i = 0; i < _result.length; i++) {
        for (int j = 0; j < _result.length; j++) {
          _getPolyline(
            i,
            _result[i].latLng.latitude,
            _result[i].latLng.longitude,
            _result[j].latLng.latitude,
            _result[j].latLng.longitude,
            _result[i].serial,
            _result[i].description,
            _result[j].description,
            _result[j].serial,
          );
        }
      }
    });
  }

  var rng = new Random();

  _addPolyLine() {
    for (int i = 0; i < Routes.RouteList.length; i++) {
      Polyline polyline = Polyline(
          polylineId: PolylineId(i.toString()),
          color: Colors.blueAccent.withOpacity(0.01),
          points: Routes.RouteList[i].routeSegmentList);
      // polylines.add(polyline);
    }

    setState(() {});
  }

  _getPolyline(time, startLat, startLong, endLat, endLong, startSerial,
      startDescription, endDescription, endSerial) async {
    /*await sleep1(time * 1000);
    List<PointLatLng> result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPiKey, startLat, startLong, endLat, endLong);
    if (result.isNotEmpty) {
      result.forEach((PointLatLng point) {
        // THIS IS FOR SAVED DATA
       // polylineCoordinates.addAll(Routes.RouteList[0].routeSegmentList);//LatLng(point.latitude, point.longitude));
      
     //   polylineCoordinates.addAll(Routes.RouteList[111].routeSegmentList);//LatLng(point.latitude, point.longitude));
      });
    }
    String lines = "";
    lines+="RouteList.add(\n";
    lines+="new Route(\n";
    lines+="  new Station(\n";
    lines+="    new LatLng(" + startLat.toString() + "," + startLong.toString() + "),\n";
    lines+="    \"" + startSerial.toString() + "\", \"" + startDescription.toString() + "\"),\n";
    lines+="  new Station(\n";
    lines+="    new LatLng(" + endLat.toString() + "," + endLong.toString() + "),\n";
    lines+="    \"" + endSerial.toString() + "\", \"" + endDescription.toString() + "\"),\n";
    lines+="[\n";
    for (int i = 0; i < result.length; i++) {
      lines+="new LatLng(" +
          result[i].latitude.toString() +
          "," +
          result[i].longitude.toString() +
          "),\n";

      // List<LatLng> latLngList = [
    }
    lines+="]\n";
    lines+="     ));\n";
    post("http://szabto.com/lo.php",body:lines);
    
*/
    _addPolyLine();
  }

  static final CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  static CameraPosition _kLake = CameraPosition(
      bearing: 192.8334901395799,
      target: LatLng(37.43296265331129, -122.08832357078792),
      tilt: 59.440717697143555,
      zoom: 5);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: SafeArea(
          child: Stack(children: [
        GoogleMap(
            circles: circles,
            polylines: Set<Polyline>.of(polylines),
            mapType: MapType.normal,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            }),
        Positioned(child: Container(height: 50, child: TimeSpanSlider())),
      ])),
      // markers: Set<Marker>.of(stationMarkers.values))),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToTheLake,
        label: Text('Go To Helsinki!'),
        icon: Icon(Icons.location_city),
      ),
    );
  }

  Future<void> _goToTheLake() async {
    final GoogleMapController controller = await _controller.future;
    var camPos =
        CameraPosition(target: LatLng(60.169739, 24.937578), zoom: 13.6);
    var style = await GetMapStyle();
    controller.setMapStyle(style);
    controller.animateCamera(CameraUpdate.newCameraPosition(camPos));
  }

  Future sleep1(int time) {
    return new Future.delayed(Duration(milliseconds: time), () => "1");
  }
}
