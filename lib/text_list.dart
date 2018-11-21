import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';

class TextListPage extends StatefulWidget {
  TextListPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  TextListState createState() => new TextListState();
}

class TextListState extends State<TextListPage> {
  Future<List> _dataFuture;

  Future<List> loadFeeds() async {
    List<String> resultList = ['曾经的你', '再见理想', '平凡之路', '两天'];
    return resultList;
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = loadFeeds();
  }

  @override
  Widget build(BuildContext context) {
    return new FutureBuilder(
        future: _dataFuture,
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.active:
              return new Text("active");
            case ConnectionState.none:
              return new Center(
                child: new Text("none"),
              );
            case ConnectionState.waiting:
              return new Center(
                child: new CupertinoActivityIndicator(),
              );
            default:
              if (snapshot.hasError) {
                debugPrint("${snapshot.error}");
                return new Center(
                  child: new Text('Error: ${snapshot.error}'),
                );
              } else {
                List data = snapshot.data;
                if (null == data || data.length == 0) {
                  return new Center(
                    child: new Text('No Data'),
                  );
                }
                List<Widget> columns = <Widget>[];
                data.forEach((name) {
                  columns.add(new ListTile(
                    leading: new CircleAvatar(
                      backgroundColor: Colors.brown.shade800,
                      child: new Text(name.substring(0, 1)),
                    ),
                    title: new Text(name),
                    trailing: const Icon(Icons.music_note),
//                        onTap: (){
//                          Navigator.push(this.context,
//                              new MaterialPageRoute(builder: (BuildContext context) {
//                                return new Scaffold(
//                                    appBar: new AppBar(
//                                      title: new Text(name),
//                                    ),
//                                    body: new DetailPage(
//                                    ));
//                              }));
//                        },
                  ));
                  columns.add(const Divider());
                });
                return new ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20.0),
                  children: columns,
                );
              }
          }
        });
  }
}
