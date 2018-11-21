import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui;
import 'imgcrop_icons.dart';

class ResultPage extends StatefulWidget {
  ResultPage({Key key, this.title, this.image, this.ocrContent})
      : super(key: key);
  final String title;
  final ui.Image image;
  final List<String> ocrContent;

  @override
  ResultState createState() => new ResultState();
}

class ResultState extends State<ResultPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var picHeight = 260.0;
    var scrollHeight = height - (260.0 + 120.0);
    return new Scaffold(
        body: new Center(
            child: new Stack(children: <Widget>[
      new Container(
        child: new Column(children: [
          new Container(
              child: new RawImage(
                image: widget.image,
                scale: 0.5,
              ),
              padding:
                  const EdgeInsets.only(left: 20.0, top: 30.0, right: 20.0),
              height: picHeight),
          new Container(
            color: Colors.white,
            margin: new EdgeInsets.only(top: 60.0),
            padding: new EdgeInsets.all(7.0),
            height: scrollHeight,
            child: new ConstrainedBox(
              constraints: new BoxConstraints(
                minHeight: scrollHeight,
                maxHeight: scrollHeight,
              ),
              child: new SingleChildScrollView(
                scrollDirection: Axis.vertical,
                reverse: true,
                child: new Text(widget.ocrContent.join("/n").toString()),
              ),
            ),
          )
        ]),
      ),
      new Positioned(
        top: 30.0,
        height: 40.0,
        width: 40.0,
        left: 10.0,
        child: new RaisedButton(
            onPressed: () => Navigator.pop(context, ""),
            padding: EdgeInsets.all(10.0),
            splashColor: Colors.white,
            shape: new RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(40.0))),
            child: new Icon(Imgcrop.back, size: 20.0, color: Colors.red)),
      ),
    ])));
  }
}
