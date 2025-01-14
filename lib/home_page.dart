import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String apiUrl = "https://robotiotpy.onrender.com/api/v1/getQuestions";
  late Future<List<dynamic>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _questionsFuture = fetchQuestions();
  }

  void _refreshData() {
    setState(() {
      _questionsFuture = fetchQuestions();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memperbarui data...'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  Future<List<dynamic>> fetchQuestions() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      data.sort((a, b) => parseDate(b['timestamp']).compareTo(parseDate(a['timestamp'])));
      return data;
    } else {
      throw Exception("Failed to load questions");
    }
  }

  String categorizeQuestion(String question) {
    question = question.toLowerCase();
    if (question.contains('bagaimana') || question.contains('apa') || question.contains('kenapa')) {
      return 'Informasi';
    } else if (question.contains('bisa')) {
      return 'Izin';
    } else if (question.contains('dimana') || question.contains('kapan')) {
      return 'Lokasi/Waktu';
    } else if (question.contains('?')) {
      return 'Pertanyaan General';
    }
    return 'Statement';
  }

  DateTime parseDate(String dateString) {
    try {
      final dateFormat = DateFormat("EEE, d MMM yyyy HH:mm:ss 'GMT'");
      return dateFormat.parse(dateString, true).toLocal();
    } catch (e) {
      throw FormatException("Invalid date format: $dateString");
    }
  }

  Map<String, int> getQuestionsByCategory(List<dynamic> data) {
    Map<String, int> categories = {};
    for (var item in data) {
      String category = categorizeQuestion(item['q']);
      categories[category] = (categories[category] ?? 0) + 1;
    }
    return categories;
  }

  Map<String, int> getQuestionsByHour(List<dynamic> data) {
    Map<String, int> hourlyData = {};
    for (var item in data) {
      DateTime date = parseDate(item['timestamp']);
      String hour = '${date.hour.toString().padLeft(2, '0')}:00';
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }
    return Map.fromEntries(hourlyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Map<String, dynamic> getAdvancedStats(List<dynamic> data) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final lastWeek = now.subtract(const Duration(days: 7));

    final todayQuestions = data.where((item) {
      final date = parseDate(item['timestamp']);
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).length;

    final yesterdayQuestions = data.where((item) {
      final date = parseDate(item['timestamp']);
      return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    }).length;

    final weeklyQuestions = data.where((item) {
      final date = parseDate(item['timestamp']);
      return date.isAfter(lastWeek);
    }).length;

    final growthRate = yesterdayQuestions > 0 
      ? ((todayQuestions - yesterdayQuestions) / yesterdayQuestions * 100).toStringAsFixed(1)
      : '0';

    return {
      'today': todayQuestions,
      'yesterday': yesterdayQuestions,
      'weekly': weeklyQuestions,
      'dailyAverage': (weeklyQuestions / 7).toStringAsFixed(1),
      'growthRate': growthRate,
    };
  }

  List<PieChartSectionData> getSections(Map<String, int> data) {
    List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.purple];
    int total = data.values.reduce((a, b) => a + b);
    
    return data.entries.map((entry) {
      int index = data.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${(entry.value / total * 100).toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 100,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    }).toList();
  }

  List<BarChartGroupData> getHourlyBarGroups(Map<String, int> hourlyData) {
    return hourlyData.entries.map((entry) {
      int x = int.parse(entry.key.split(':')[0]);
      return BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.blue,
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Monitoring"),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: _refreshData,
          backgroundColor: Colors.blue,
          child: const Icon(Icons.refresh),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
        child: FutureBuilder<List<dynamic>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else {
              final data = snapshot.data!;
              final categoryData = getQuestionsByCategory(data);
              final hourlyData = getQuestionsByHour(data);
              final advancedStats = getAdvancedStats(data);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard(
                                "Hari Ini",
                                advancedStats['today'].toString(),
                                Icons.today,
                              ),
                              _buildStatCard(
                                "Minggu Ini",
                                advancedStats['weekly'].toString(),
                                Icons.date_range,
                              ),
                              _buildStatCard(
                                "Rata-rata/Hari",
                                advancedStats['dailyAverage'],
                                Icons.trending_up,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard(
                                "Kemarin",
                                advancedStats['yesterday'].toString(),
                                Icons.history,
                              ),
                              _buildStatCard(
                                "Pertumbuhan",
                                "${advancedStats['growthRate']}%",
                                Icons.show_chart,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Distribusi Pertanyaan per Jam",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 300,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: hourlyData.values.reduce((a, b) => a > b ? a : b).toDouble(),
                                    barGroups: getHourlyBarGroups(hourlyData),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: true),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            return Text('${value.toInt()}:00');
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Distribusi Kategori Pertanyaan",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 300,
                                child: PieChart(
                                  PieChartData(
                                    sections: getSections(categoryData),
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLegend(categoryData),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Pertanyaan Terbaru",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...data.take(10).map((item) => _buildQuestionCard(item)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80), // Space for FloatingActionButton
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, int> data) {
    List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.purple];
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: data.entries.map((entry) {
        int index = data.keys.toList().indexOf(entry.key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              color: colors[index % colors.length],
            ),
            const SizedBox(width: 4),
            Text('${entry.key}: ${entry.value}'),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildQuestionCard(dynamic item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(item['q']),
        subtitle: Text(
          DateFormat('dd MMM yyyy HH:mm').format(parseDate(item['timestamp'])),
        ),
        trailing: Chip(
          label: Text(
            categorizeQuestion(item['q']),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }
}