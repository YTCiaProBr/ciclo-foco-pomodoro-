class TaskModel {

  List<TaskModel> tasks = [];

  String title = '';
  String description = '';
  int cyclesFinished = 0;
  int cycles = 0;

  TaskModel({
    required this.title,
    required this.description,
    required this.cycles,
    required this.cyclesFinished,
  });

  void setTasks(List<TaskModel> taskList) {
    tasks = taskList;
  }

  List<TaskModel> getTasks() {
    return tasks;
  }

  void addTask(TaskModel task) {
    tasks.insert(0,task);
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
    };

    return taskMap;
  }

  TaskModel fromMap(Map taskMap) {
    TaskModel task = TaskModel(
      title: taskMap['title'],
      description: taskMap['description'],
      cycles:  taskMap['cycles'],
      cyclesFinished: taskMap['cyclesfinished'],
    );

    return task;
  }
}