import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/storage.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider(this._storage) {
    _tasks = _storage.getAllTasks();
  }

  /// Re-reads everything from storage (used after "Reset all data").
  void reload() {
    _tasks = _storage.getAllTasks();
    notifyListeners();
  }

  final StorageService _storage;
  List<Task> _tasks = [];

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Task> get openTasks => _tasks.where((t) => !t.isDone).toList();
  List<Task> get doneTasks => _tasks.where((t) => t.isDone).toList();

  /// The task with [id], or null if it was deleted.
  Task? byId(String? id) => _tasks.where((t) => t.id == id).firstOrNull;

  Future<void> addTask(Task task) async {
    _tasks.add(task);
    notifyListeners();
    await _storage.saveTask(task);
  }

  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    _tasks[index] = task;
    notifyListeners();
    await _storage.saveTask(task);
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _storage.deleteTask(id);
  }
}
