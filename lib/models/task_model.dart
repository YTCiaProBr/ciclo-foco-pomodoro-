import 'package:uuid/uuid.dart';

class TaskModel {

  List<TaskModel> tasks = [];

  final String id = Uuid().v7();
  String title = '';
  String description = '';
  int cyclesFinished = 0;
  int cycles = 0;
  bool isCompleted = false;

  static TaskModel empty = TaskModel(
    title: '',
    description: '',
    cycles: 1,
    cyclesFinished: 0,
    isCompleted: false,
  );

  TaskModel({
    required this.title,
    required this.description,
    required this.cycles,
    required this.cyclesFinished,
    required this.isCompleted,
  });

  List<TaskModel> getTasks() {
    return tasks;
  }

  void setTasks(List newTasks) {
    for (var task in newTasks) {
      tasks.add(fromMap(task));
    }
  }

  void addTask(TaskModel task) {
    tasks.insert(0,task);
  }                                                   

    void propagateAddCycle() {
    for (TaskModel task in tasks) {
      task.addCycle();
      if (task.isCompleted) sendTaskToEnd(task);
    }
  }

  void addCycle() {
    if (cyclesFinished < cycles) {
        cyclesFinished++;
    }

    if (cyclesFinished == cycles) {
      isCompleted = true;
    }
  }

  void editTask(int taskIdx, TaskModel editedTask) {
    if (taskIdx < 0 || taskIdx > tasks.length) {
      return;
      
    }

    tasks[taskIdx] = editedTask;
  }

  void sendTaskToEnd(TaskModel task) {
    tasks.remove(task);
    tasks.add(task);
  }

  void removeTask(TaskModel task) {
    tasks.remove(task);
  }

  Map<String, dynamic> toMap(TaskModel task) {
    Map<String,dynamic> taskMap = {
      'title': task.title,
      'description': task.description,
      'cyclesfinished': task.cyclesFinished,
      'cycles': task.cycles,
      'iscompleted': task.isCompleted,
    };

    return taskMap;
  }

  TaskModel fromMap(Map<String, dynamic> taskMap) {
    TaskModel task = TaskModel(
      title: taskMap['title'],
      description: taskMap['description'],
      cycles:  taskMap['cycles'],
      cyclesFinished: taskMap['cyclesfinished'],
      isCompleted: taskMap['iscompleted'],
    );

    return task;
  }
}