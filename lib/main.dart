import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' show parse;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, String> programs = {};
  Map<String, String> sessions = {};
  String? selectedProgram;
  String? selectedSession;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getPrograms();
  }

  Future<void> getPrograms() async {
    setState(() {
      isLoading = true;
    });

    try {
      var url = Uri.parse("http://172.16.100.34/mis/modules/provisional_ug/action.php");
      var response = await http.post(url, body: {'action': "programAll"});

      if (response.statusCode == 200) {
        var document = parse(json.decode(response.body));
        var options = document.getElementsByTagName('option');

        setState(() {
          for (var option in options) {
            String value = option.attributes['value'] ?? '';
            String text = option.text.trim();
            if (value.isNotEmpty && text != "Select Program...") {
              programs[text] = value;
            }
          }
        });
      } else {
        throw Exception('Failed to load programs');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getSessions(String programId) async {
    setState(() {
      isLoading = true;
      sessions.clear();
      selectedSession = null;
    });

    try {
      var url = Uri.parse("http://172.16.100.34/mis/modules/provisional_ug/action.php");
      var response = await http.post(url, body: {
        'program_id': programId,
        'action': "sessionAll",
      });

      if (response.statusCode == 200) {
        var document = parse(json.decode(response.body));
        var options = document.getElementsByTagName('option');

        setState(() {
          for (var option in options) {
            String value = option.attributes['value'] ?? '';
            String text = option.text.trim().replaceAll('\xa0', '');
            if (value.isNotEmpty && text != "Select Semester...") {
              sessions[text] = value;
            }
          }
        });
      } else {
        throw Exception('Failed to load sessions');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> scrapeAttendance(String id) async {
    setState(() {
      isLoading = true;
    });

    try {
      var url = Uri.parse("http://172.16.100.34/mis/modules/provisional_ug/action.php");
      var response = await http.post(url, body: {
        'attendance_report_id': id,
        'action': "fetchAll"
      });

      if (response.statusCode == 200) {
        String htmlContent = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceWebView(htmlContent: htmlContent),
          ),
        );
      } else {
        throw Exception('Failed to fetch attendance data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Attendance'),
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Program', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedProgram,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedProgram = newValue;
                                if (newValue != null) {
                                  getSessions(programs[newValue]!);
                                }
                              });
                            },
                            items: programs.keys.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Session', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedSession,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedSession = newValue;
                              });
                            },
                            items: sessions.keys.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (selectedProgram != null && selectedSession != null)
                        ? () => scrapeAttendance(sessions[selectedSession]!)
                        : null,
                    child: Text('Get Attendance'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class AttendanceWebView extends StatefulWidget {
  final String htmlContent;

  AttendanceWebView({required this.htmlContent});

  @override
  _AttendanceWebViewState createState() => _AttendanceWebViewState();
}

class _AttendanceWebViewState extends State<AttendanceWebView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Report'),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}