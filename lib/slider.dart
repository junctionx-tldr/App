// This code is from here: https://stackoverflow.com/questions/52987440/flutter-custom-range-slider
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';


void main() {
  // generate random bars
  runApp(MySlider());
}
 var barWidth = 0.0;

class MySlider extends StatelessWidget {  
  @override
  Widget build(BuildContext context) {
     
    return MaterialApp(
      home: TimeSpanSlider(),
    );
  }
}

class TimeSpanSlider extends StatefulWidget {

  

  @override
  State<StatefulWidget> createState() => TimeSpanSliderState();
}

class TimeSpanSliderState extends State<TimeSpanSlider> {
  
static List<int> bars = [];

  double bar1Position = 1.0;

@override
  void initState() { 
    
    super.initState();
        Random r = Random();
      //for (var i = 0; i < 50; i++) {
        //bars.add(r.nextInt(50));
       
      //}
  }

var currentHour = 1;
    Timer _timer=null; 


  void startTimer() {
    if(_timer!=null){
      _timer.cancel();
      _timer=null;
    }
    _timer = new Timer.periodic(
       Duration(milliseconds: 500),
      
      (Timer timer)  {
        _timer.cancel();
        _timer=null;
        print("Timer has finished"+currentHour.toString());
        MapSampleState.ChangeHour(currentHour);
      }
    );
  }
  @override
  Widget build(BuildContext context) {
    int i = 0;
 barWidth = (MediaQuery.of(context).size.width/24);
      print("BARWIDTH:" + barWidth.toString());
      print("MQ:" + MediaQuery.of(context).size.width.toString());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Stack(
          
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
               
              children: bars.map((int height) {
                

                return Container(
                  color: Colors.blueAccent,
                  height: height.toDouble(),
                  width: barWidth,
                );
              }).toList(),
            ),
            
            Bar(
              position: bar1Position,
              callback: (DragUpdateDetails details) {
                
                setState(() {
                  
                  bar1Position += details.delta.dx;
                  currentHour = ((bar1Position/(24*barWidth))*24).round();
                  startTimer();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  
}

class Bar extends StatelessWidget {
  final double position;
  final GestureDragUpdateCallback callback;

  Bar({this.position, this.callback});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: position >= 0.0 ? position : 0.0),
      child: GestureDetector(
        onHorizontalDragUpdate: callback,
        child: Container(
          color: Colors.orangeAccent,
          height: 200.0,
          width: barWidth,
        ),
      ),
    );
  }
}