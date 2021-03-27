import 'package:fludip/provider/blubber/blubberThreadViewer.dart';
import 'package:fludip/provider/blubberProvider.dart';
import 'package:fludip/util/str.dart';
import 'package:flutter/material.dart';
import 'package:fludip/navdrawer/navDrawer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

///Community page = blubber page
class CommunityPage extends StatefulWidget {
  List<dynamic> _threads;

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Widget> _buildOverview() {
    List<Widget> widgets = <Widget>[];
    if (widget._threads == null || widget._threads.isEmpty) {
      return widgets;
    }

    widget._threads.forEach((thread) {
      String avatarUrl = thread["avatar"];
      Widget leading;
      if (avatarUrl.contains(".svg")) {
        leading = SvgPicture.network(
          thread["avatar"],
          width: 30,
          height: 30,
        );
      } else {
        leading = Image.network(
          thread["avatar"],
          width: 30,
          height: 30,
        );
      }

      widgets.add(ListTile(
        leading: leading,
        title: Text(thread["name"]),
        subtitle: Text(StringUtil.fromUnixTime(thread["timestamp"] * 1000, "dd.MM.yyyy HH:mm")),
        onTap: () {
          if (!Provider.of<BlubberProvider>(context, listen: false).threadInitialized(thread["name"])) {
            Provider.of<BlubberProvider>(context, listen: false).initThread(thread["name"]);
          }

          Navigator.push(context, navRoute(BlubberThreadViewer(name: thread["name"])));
        },
      ));

      widgets.add(Divider());
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    widget._threads = Provider.of<BlubberProvider>(context).getThreads();

    return Scaffold(
      appBar: AppBar(
        title: Text("Community"),
      ),
      body: Center(
        child: RefreshIndicator(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            children: _buildOverview(),
          ),
          onRefresh: () async {},
        ),
      ),
      drawer: NavDrawer(),
    );
  }
}
