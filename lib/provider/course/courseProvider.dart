import 'dart:convert';
import 'dart:async';

import 'package:fludip/provider/course/coursePreviewModel.dart';
import 'package:fludip/provider/course/semester/semesterFilter.dart';
import 'package:fludip/provider/course/semester/semesterProvider.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';

import 'package:fludip/net/webClient.dart';
import 'package:fludip/provider/course/courseModel.dart';
import 'package:fludip/provider/course/semester/semesterModel.dart';
import 'package:provider/provider.dart';

///This provider provides the data for the courses themselves *and* the overview tab
class CourseProvider extends ChangeNotifier {
  Map<Semester, List<Course>> _courses;

  final WebClient _client = WebClient();

  //Returns a list of semesters that haven't been initialised yet
  //This way we only initialise the ones we don't already have data of
  List<Semester> initialized(List<Semester> semesters) {
    if (_courses == null) {
      return semesters;
    }

    List<Semester> uninitialised = <Semester>[];
    for (Semester sem in semesters) {
      if (!_courses.containsKey(sem)) {
        uninitialised.add(sem);
      }
    }
    return uninitialised;
  }

  Future<List<Course>> get(BuildContext context, String userID, List<Semester> semesters) async {
    List<Semester> uninitialised = initialized(semesters);
    if (uninitialised.isNotEmpty) {
      await forceUpdate(context, userID, uninitialised);
    }

    //Filter courses by the given list of semesters
    List<Course> courses = <Course>[];
    semesters.forEach((semester) {
      for (Course course in _courses[semester]) {
        if (!courses.contains(course)) {
          courses.add(course);
        }
      }
    });
    return Future<List<Course>>.value(courses);
  }

  String getLogo(String courseID) {
    return _client.server.webAddress + "/pictures/course/" + courseID + "_medium.png";
  }

  //TODO maybe add different images for each type of course
  String getEmptyLogo(CourseType type) {
    return _client.server.webAddress +
        "/pictures/course/" +
        (type == CourseType.StudyGroup ? "studygroup_medium.png" : "nobody_medium.png");
  }

  Future<void> forceUpdate(BuildContext context, String userID, List<Semester> semesters) async {
    _courses ??= <Semester, List<Course>>{};

    await Future.forEach(semesters, (Semester semester) async {
      if (semester == null) {
        return;
      }

      _courses.remove(semester);

      String route = "/user/$userID/courses";

      http.Response res = await _client.httpGet(route, APIType.REST, urlParams: {"semester": semester.semesterID});
      Map<String, dynamic> decoded = jsonDecode(res.body);
      Map<String, dynamic> courseMap = decoded["collection"];

      await Future.forEach(courseMap.keys, (courseKey) async {
        Map<String, dynamic> courseData = courseMap[courseKey];

        String startSemesterID = courseData["start_semester"].toString().split("/").last;
        SemesterFilter sfilter = SemesterFilter(FilterType.SPECIFIC, startSemesterID);
        Semester start = Provider.of<SemesterProvider>(context, listen: false).get(sfilter).first;

        String endSemesterID = courseData["end_semester"].toString().split("/").last;
        SemesterFilter efilter = SemesterFilter(FilterType.SPECIFIC, endSemesterID);
        Semester end = Provider.of<SemesterProvider>(context, listen: false).get(efilter).first;

        Course course = Course.fromMap(courseData, start, end);

        if (!_courses.containsKey(semester)) {
          _courses[semester] = <Course>[];
        }

        _courses[semester].add(course);
      });

      _courses[semester].sort((Course a, Course b) {
        return (a.color.value - b.color.value) + (b.number.compareTo(a.number));
      });
    });

    notifyListeners();
  }

  Future<List<CoursePreview>> searchFor(BuildContext context, String searchStr) async {
    List<CoursePreview> courses = <CoursePreview>[];
    if (searchStr == null || searchStr.isEmpty) {
      return courses;
    }

    http.Response response = await _client.httpGet("/courses", APIType.JSON, urlParams: <String, dynamic>{
      "filter[q]": searchStr,
      "filter[fields]": "all" //TODO add filter options http://jsonapi.elan-ev.de/?shell#schema-quot-course-memberships-quot
    });

    List<dynamic> decodedCourses = jsonDecode(response.body)["data"];

    decodedCourses.forEach((entry) {
      Map<String, dynamic> coursePreviewData = entry as Map<String, dynamic>;

      String startSemesterID = coursePreviewData["relationships"]["start-semester"]["data"]["id"];
      SemesterFilter sfilter = SemesterFilter(FilterType.SPECIFIC, startSemesterID);
      Semester start = Provider.of<SemesterProvider>(context, listen: false).get(sfilter).first;

      if (coursePreviewData["relationships"]["end-semester"] != null) {
        String endSemesterID = coursePreviewData["relationships"]["end-semester"]["data"]["id"];
        SemesterFilter efilter = SemesterFilter(FilterType.SPECIFIC, endSemesterID);
        Semester end = Provider.of<SemesterProvider>(context, listen: false).get(efilter).first;

        courses.add(CoursePreview.fromData(coursePreviewData, start, end));
      } else {
        courses.add(CoursePreview.fromData(coursePreviewData, start, null));
      }
    });

    notifyListeners();
    return Future<List<CoursePreview>>.value(courses);
  }

  Future<http.Response> signup(String courseID) async {
    //There doesn't seem to be a route in REST or JSON for signing up for a course
    //So this 'imitates' the action done in a browser

    //Extract the security token from the html page
    http.Response res = await http.get(
      Uri.parse(_client.server.webAddress + "/dispatch.php/course/enrolment/apply/$courseID"),
      headers: {
        "Cookie": _client.sessionCookie,
      },
    );
    String tag = "<input type=\"hidden\" name=\"security_token\" value=\"";
    int start = res.body.indexOf(tag) + tag.length;
    int end = res.body.indexOf(">", start) - 1;

    String securityToken = res.body.substring(start, end);

    return http.post(Uri.parse(_client.server.webAddress + "/dispatch.php/course/enrolment/apply/$courseID"), headers: {
      "Cookie": _client.sessionCookie,
    }, body: {
      "apply": "1",
      "security_token": securityToken,
      "yes": "",
    });
  }

  Future<http.Response> signout(String courseID) async {
    //There doesn't seem to be a route in REST or JSON for siging out of a course either
    //So this 'imitates' the action done in a browser

    //Extract the security token and studip ticket(?) from the html page
    http.Response res = await http.get(
      Uri.parse(_client.server.webAddress + "/dispatch.php/my_courses/decline/$courseID?cmd=suppose_to_kill"),
      headers: {
        "Cookie": _client.sessionCookie,
      },
    );

    String secTag = "<input type=\"hidden\" name=\"security_token\" value=\"";
    int secStart = res.body.indexOf(secTag) + secTag.length;
    int secEnd = res.body.indexOf(">", secStart) - 1;

    String securityToken = res.body.substring(secStart, secEnd);

    String ticketTag = "<input type=\"hidden\" name=\"studipticket\" value=\"";
    int ticketStart = res.body.indexOf(ticketTag) + ticketTag.length;
    int ticketEnd = res.body.indexOf(">", ticketStart) - 1;

    String studipTicket = res.body.substring(ticketStart, ticketEnd);

    return http.post(Uri.parse(_client.server.webAddress + "/dispatch.php/my_courses/decline/$courseID"), headers: {
      "Cookie": _client.sessionCookie,
    }, body: {
      "security_token": securityToken,
      "cmd": "kill",
      "studipticket": studipTicket,
    });
  }

  void resetCache() {
    _courses = null;
  }
}
