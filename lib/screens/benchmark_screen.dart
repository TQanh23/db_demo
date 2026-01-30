import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/benchmark_service.dart';

class BenchmarkScreen extends StatefulWidget {
  final BenchmarkService benchmarkService;

  const BenchmarkScreen({super.key, required this.benchmarkService});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> with SingleTickerProviderStateMixin {
  int _recordCount = 1000;
  final List<int> _counts = [1000, 10000, 50000];
  
  bool _isLoading = false;
  Map<String, int> _results = {}; 
  String _currentOperation = 'Ready';

  // Animation controller for FPS/Rotation
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _runBenchmark(String operation) async {
    setState(() {
      _isLoading = true;
      _currentOperation = operation;
      _results = {}; // Clear old results
    });

    // Add a small delay to let UI update
    await Future.delayed(const Duration(milliseconds: 100));

    Map<String, int> results = {};
    try {
      if (operation == 'Batch Insert') {
        results = await widget.benchmarkService.benchmarkInsert(_recordCount);
      } else if (operation == 'Batch Read') {
        results = await widget.benchmarkService.benchmarkRead();
      } else if (operation == 'Batch Delete') {
        results = await widget.benchmarkService.benchmarkDelete();
      }
    } catch (e) {
      debugPrint('Benchmark Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _results = results;
        _currentOperation = 'Finished $operation';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Benchmark Arena', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Transparent for gradient
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF2C3E50), const Color(0xFF000000)]
                : [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildControlPanel(),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                         _buildProgressIndicator(),
                        const SizedBox(height: 20),
                        _buildResultsTable(),
                        const SizedBox(height: 30),
                        if (_results.isNotEmpty)
                          SizedBox(
                            height: 300,
                            child: _buildChart(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Records:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<int>(
                  value: _recordCount,
                  items: _counts.map((c) => DropdownMenuItem(value: c, child: Text('$c'))).toList(),
                  onChanged: _isLoading ? null : (val) => setState(() => _recordCount = val!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, // Horizontal spacing
              runSpacing: 12, // Vertical spacing
              alignment: WrapAlignment.center,
              children: [
                _buildActionButton('Batch Insert', Icons.file_download, Colors.green),
                _buildActionButton('Batch Read', Icons.file_upload, Colors.blue),
                _buildActionButton('Batch Delete', Icons.delete_forever, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _runBenchmark(label),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color, // Text & Icon color
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        if (_isLoading) ...[
          const Text('Benchmarking... UI might freeze if Main Thread is blocked!'),
          const SizedBox(height: 10),
        ],
        
        // Always rotating indicator to show UI responsiveness
        RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isLoading ? Colors.red : Colors.green,
                width: 3,
                style: BorderStyle.solid
              ),
              gradient: SweepGradient(colors: [
                 Colors.transparent, 
                 _isLoading ? Colors.red : Colors.green
              ]),
            ),
            child: const Icon(Icons.speed, size: 20),
          ),
        ),
        const SizedBox(height: 5),
        const Text('UI Responsiveness Check', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildResultsTable() {
    if (_results.isEmpty && !_isLoading) {
      return const Text('Press a button to start benchmark', style: TextStyle(color: Colors.grey));
    }
    
    // Find winner
    String winner = '';
    int minTime = 99999999;
    
    if (_results.isNotEmpty) {
      _results.forEach((k, v) {
        if (v < minTime) {
          minTime = v;
          winner = k;
        }
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Results for $_currentOperation ($_recordCount records)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            if (_isLoading) 
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else
              Column(
                children: _results.entries.map((e) {
                  final isWinner = e.key == winner;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      e.key == 'Hive' ? Icons.inventory_2 
                      : e.key == 'SQLite' ? Icons.table_chart 
                      : Icons.rocket_launch,
                      color: e.key == 'Hive' ? Colors.orange 
                      : e.key == 'SQLite' ? Colors.blue 
                      : Colors.purple,
                    ),
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${e.value} ms', style: const TextStyle(fontSize: 16)),
                        if (isWinner) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                        ]
                      ],
                    ),
                  );
                }).toList(),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Convert results to BarChartGroupData
    final entries = _results.entries.toList();
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (entries.map((e) => e.value).reduce(max) * 1.2).toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < entries.length) {
                   return Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text(entries[value.toInt()].key, style: const TextStyle(fontWeight: FontWeight.bold)),
                   );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          Color color = Colors.grey;
          if (data.key == 'Hive') color = Colors.orange;
          if (data.key == 'SQLite') color = Colors.blue;
          if (data.key == 'Isar') color = Colors.purple;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.value.toDouble(),
                color: color,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: (entries.map((e) => e.value).reduce(max) * 1.2).toDouble(),
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }).toList(),
      ),
    );
  }
}
