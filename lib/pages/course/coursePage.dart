import 'package:fludip/provider/course/semester/semesterFilter.dart';
import 'package:fludip/provider/course/semester/semesterModel.dart';
import 'package:fludip/pages/course/tabs/files.dart';
import 'package:fludip/pages/course/tabs/forum/forum.dart';
import 'package:fludip/pages/course/tabs/members.dart';
import 'package:fludip/pages/course/tabs/overview.dart';
import 'package:fludip/pages/community/blubberThreadViewer.dart';
import 'package:fludip/provider/blubber/blubberProvider.dart';
import 'package:fludip/provider/course/overview/courseModel.dart';
import 'package:fludip/provider/course/overview/courseProvider.dart';
import 'package:fludip/provider/course/semester/semesterProvider.dart';
import 'package:fludip/util/widgets/Nothing.dart';
import 'package:flutter/material.dart';
import 'package:fludip/navdrawer/navDrawer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:transparent_image/transparent_image.dart';

//Convenience class to be used in grid view below
class GridButton extends StatelessWidget {
  final IconData _icon;
  final String _caption;
  final Color _color;
  final Function _onTap;

  GridButton({@required icon, @required caption, @required color, @required onTap})
      : _icon = icon,
        _caption = caption,
        _color = color,
        _onTap = onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _color,
      child: InkWell(
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_icon),
              Text(
                _caption,
                style: GoogleFonts.montserrat(),
              ),
            ],
          ),
        ),
        onTap: _onTap,
      ),
    );
  }
}

class CoursePage extends StatelessWidget {
  final String userID;

  CoursePage(String uID) : userID = uID;

  List<Widget> _buildListEntries(BuildContext context, List<Course> courses) {
    if (courses == null || courses.isEmpty) {
      return <Widget>[Nothing()];
    }

    List<Widget> widgets = <Widget>[];

    int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    courses.sort((a, b) {
      return (b.endSemester != null ? b.endSemester.end : now) - (a.endSemester != null ? a.endSemester.end : now);
    });

    Semester current = courses.first.startSemester;
    widgets.add(Text(
      current.title,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w300),
      textAlign: TextAlign.center,
    ));

    courses.forEach((course) {
      if (course.endSemester == null) {
        course.endSemester =
            Provider.of<SemesterProvider>(context, listen: false).get(SemesterFilter(FilterType.CURRENT, null)).first;
      }

      if (course.endSemester.semesterID != current.semesterID) {
        widgets.add(Text(
          course.endSemester.title,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w300),
          textAlign: TextAlign.center,
        ));
        current = course.endSemester;
      }

      //Ugly, but https://github.com/flutter/flutter/issues/81931 is still open
      //This means we have to check in advance if the url is a valid image resource
      //since it doesn't appear possible to handle the error somehow
      //Both wrapping in try-catch and using the errorBuilder don't work
      String url = Provider.of<CourseProvider>(context, listen: false).getLogo(course.courseID);
      var response = http.get(Uri.parse(url));

      //TODO: List of options for which new content appeared, for example a new file upload
      widgets.add(
        Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: course.color, width: 7.5))),
          child: ExpansionTile(
            title: Container(
              child: Row(
                children: [
                  FutureBuilder(
                    future: response,
                    builder: (BuildContext context, AsyncSnapshot<http.Response> snapshot) {
                      if (snapshot.hasData) {
                        if (snapshot.data.statusCode == 200) {
                          return FadeInImage(
                            placeholder: MemoryImage(kTransparentImage),
                            image: MemoryImage(snapshot.data.bodyBytes),
                            width: 32,
                            height: 32,
                          );
                        }
                        return FadeInImage(
                          placeholder: MemoryImage(kTransparentImage),
                          image: NetworkImage(Provider.of<CourseProvider>(context, listen: false).getEmptyLogo(course.type)),
                          width: 32,
                          height: 32,
                        );
                      }
                      return CircularProgressIndicator();
                    },
                  ),
                  VerticalDivider(),
                  Flexible(
                    child: Text(
                      course.title,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              GridView.count(
                crossAxisCount: 4,
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                children: [
                  GridButton(
                    icon: Icons.new_releases_sharp,
                    caption: "news".tr(),
                    color: Colors.white54,
                    onTap: () {
                      Navigator.push(context, navRoute(NewsTab(course: course)));
                    },
                  ),
                  GridButton(
                    icon: Icons.forum,
                    caption: "forum".tr(),
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        navRoute(ForumTab(course: course)),
                      );
                    },
                  ),
                  GridButton(
                    icon: Icons.people,
                    caption: "members".tr(),
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        navRoute(MembersTab(course: course)),
                      );
                    },
                  ),
                  GridButton(
                    icon: Icons.file_copy,
                    caption: "files".tr(),
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        navRoute(FilesTab(course: course, path: <int>[])),
                      );
                    },
                  ),
                  GridButton(
                    icon: Icons.chat,
                    caption: "blubber".tr(),
                    color: Colors.amber,
                    onTap: () async {
                      String threadName = course.title;

                      await Provider.of<BlubberProvider>(context, listen: false).getOverview();
                      Navigator.push(
                        context,
                        navRoute(
                          BlubberThreadViewer(
                            name: threadName,
                            course: course,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      );
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    SemesterFilter filter = SemesterFilter(FilterType.LAST_CURRENT, null);
    List<Semester> semesters = Provider.of<SemesterProvider>(context, listen: false).get(filter);
    Future<List<Course>> fCourses = Provider.of<CourseProvider>(context).get(context, userID, semesters);

    return Scaffold(
      appBar: AppBar(
        title: Text("event".tr(), style: GoogleFonts.montserrat()),
      ),
      body: FutureBuilder(
        future: fCourses,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Container(
              child: RefreshIndicator(
                child: ListView(
                  children: _buildListEntries(context, snapshot.data),
                ),
                onRefresh: () async {
                  return Provider.of<CourseProvider>(context, listen: false).forceUpdate(context, userID, semesters);
                },
              ),
            );
          } else {
            return Container(
              child: LinearProgressIndicator(),
            );
          }
        },
      ),
      drawer: NavDrawer(),
    );
  }
}
