import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pomodoro_timer/models/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown, // opcional (permite virar de cabeça pra baixo)
  ]);

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHome(),
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {

  // ---------------------------------

  late final SharedPreferences prefs;

  late ConfigsOverlay _configsScreen;
  bool _showConfigs = false;
  //late newTaskScreen _newTaskScreen;
  bool _showEditTask = false;
  
  late TaskModel _taskManager;
  TaskModel toEditTask = TaskModel.empty;
  int toEditTaskIdx = -1;
  bool toEdit = false;

  
  String _startIcon = '';
  final String _playIcon = 'assets/icons/play.svg';
  final String _pauseIcon = 'assets/icons/pause.svg';

  Timer? _pomoTimer;  

  String _formatedTime = '00:00';
  int _pomoTime = 25;
  int _breakTime = 5;
  int _currentTime = 0;
  int _timer = 0;
  double _timerProgress = 0;

  bool isPomo = true; 
  bool _autoStartTimersOn = false;
  bool _timerRunning = false;
  bool _playAlarmsOn = true;

  Map alarms = {
    '1': 'audio/alarm.mp3',
    '2': 'audio/bird.mp3',
    '3': 'audio/error.mp3',
    '4': 'audio/soft_synth.mp3',
    '5': 'audio/wind_chime.mp3',
  };

  String _pomoAlarm = '1';
  String _breakAlarm = '4';

  final Color _breakColor = Color.fromARGB(255, 55, 154, 247);
  final Color _pomoColor = Color(0xffF7374F);
  Color _bgColor = Color(0xffF7374F);
  
  AudioPlayer? _audioPlayer;

  late dynamic _prefsFuture;

  // ---------------------------------

  @override
  void initState() {

    super.initState();

    _taskManager = TaskModel.empty;

    _configsScreen = ConfigsOverlay(home: this);
    //_newTaskScreen = newTaskScreen(home: this);
    _audioPlayer = AudioPlayer();
    _startIcon = _playIcon;
    _bgColor = _pomoColor;
    _prefsFuture = _startPrefs();
  }


  Future<void> _startPrefs() async {
    prefs = await SharedPreferences.getInstance();
    await _loadConfigs();
    await Future.delayed(const Duration(seconds: 5));
  }

  void _saveConfigs() {
    prefs.setInt('_pomoTime', _pomoTime);
    prefs.setInt('_breakTime', _breakTime);
    prefs.setBool('_autoStartTimersOn', _autoStartTimersOn);
    prefs.setBool('_playAlarmsOn', _playAlarmsOn);
    prefs.setString('_pomoAlarm', _pomoAlarm);
    prefs.setString('_breakAlarm', _breakAlarm);


    List<TaskModel> tasks = _taskManager.getTasks();
    List<Map> mapTasks = [];

    for (TaskModel task in tasks) {
      mapTasks.add(_taskManager.toMap(task));
    }

    prefs.setString('_tasks', jsonEncode(mapTasks));
  }

  Future<void> _clearConfigs() async {
    await prefs.clear();
  }

  Future<void> _loadConfigs() async {

    if (
      !prefs.containsKey('_pomoTime')
      ) {
      return;
    }

    _pomoTime = prefs.getInt('_pomoTime') ?? 25;
    _breakTime = prefs.getInt('_breakTime') ?? 5;
    _autoStartTimersOn = prefs.getBool('_autoStartTimersOn') ?? false;
    _playAlarmsOn = prefs.getBool('_playAlarmsOn') ?? true;
    _pomoAlarm = prefs.getString('_pomoAlarm') ?? '1';
    _breakAlarm = prefs.getString('_breakAlarm') ?? '4';
    

    String? savedTasks = prefs.getString('_tasks');

    if (savedTasks != null) {
      List loadedTasks = jsonDecode(savedTasks);
      print(loadedTasks);
      _taskManager.setTasks(loadedTasks);
    }

    //Initializes the timers
    _currentTime = _pomoTime;
    _timer = _currentTime;
    _setTimer(_pomoTime);

  }

  void _pauseTimer() {
    _pomoTimer?.cancel();
  }

  void _stopTimer() {
    setState(() {
      _timerRunning = false;
      _timerProgress = 0.0;
      _pomoTimer?.cancel();
      _setTimer(_currentTime);
      _updateFormatedTime(_timer);
    });
  }

  //Sets timer to new time
  void _setTimer(int newTime) {
    if (newTime > 999) {
      newTime = 999;
    } 
    else if (newTime < 1) {
      newTime = 1;
    } 

    _currentTime = newTime;
    _timer = _currentTime * 60;
    _updateFormatedTime(_timer);
  }

  //Updates timer that is displayed on app
  void _updateFormatedTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;

    String m = minutes.toString().padLeft(2, '0');
    String s = seconds.toString().padLeft(2, '0');
    _formatedTime = '$m:$s';
  }

  void _playAudio(String audioPath) {
    _audioPlayer?.play(AssetSource(audioPath));
  }

  //Starts counting down timer
  //MUDAR ISSO AQUI
  void _startTimer() {

    if (_pomoTimer?.isActive ?? false) return; // já está rodando

    _timerRunning = true;
    _timer--;
    _timerProgress = (_currentTime * 60 - _timer) / (_currentTime * 60);

    _updateFormatedTime(_timer);

    //Counts down the _timer variable while updating the InApp timer
    _pomoTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timer > 0) {
          _timer--;
          _timerProgress = (_currentTime * 60 - _timer) / (_currentTime * 60);

          _updateFormatedTime(_timer);
        } else {
          //Stops timer when time left finishes
          _stopTimer();
          _startIcon = _playIcon;
          
          //Swaps pomodoro to break
          if (isPomo) {
            _taskManager.propagateAddCycle();
            _saveConfigs();
            _bgColor = _breakColor;
            _setTimer(_breakTime);
            isPomo = false;
            if (_playAlarmsOn) _playAudio(alarms[_pomoAlarm]);
          } 
          
          //Swaps break to pomodoro
          else {
            _bgColor = _pomoColor;
            _setTimer(_pomoTime);
            isPomo = true;
            if (_playAlarmsOn) _playAudio(alarms[_breakAlarm]);
          }

          //Starts timer automatically
          if (_autoStartTimersOn) _startTimer();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {  

    return FutureBuilder(
      future: _prefsFuture,
      builder: (context, asyncSnapshot) {

        //Loading
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {

          return Center(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
            
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/tomato.svg',
                    width: 50,
                    height: 50,
                    colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
            
                  SizedBox(height: 20,),

                  SizedBox(
                    width: 150,
                    child: LinearProgressIndicator(
                      color: Colors.white,
                      backgroundColor: Color(0xff636363),
                      borderRadius: BorderRadius.circular(20),
                      minHeight: 5,
                      
                    ),
                  )
                ],
              ),
            ),
          );

        }

        //Loaded
        return Stack(

          children: [
            
            _mainScreen(),

            if (_showConfigs)
            _configsScreen,

            if (_showEditTask)
            newTaskScreen(
              home: this,
              title: toEditTask.title,
              description: toEditTask.description,
              cycles: toEditTask.cycles,
              cyclesFinished: toEditTask.cyclesFinished,
              toEdit: toEdit,
              editTaskIdx: toEditTaskIdx,
              ),
          ],
        );
      }
    );
  }

  Scaffold _mainScreen() {
    return Scaffold(
        
          extendBodyBehindAppBar: true,
        
          appBar: appBar(),
        
          body: AnimatedContainer(
          
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _bgColor,
            ),
            
            child: Column(
              children: [
                SizedBox(height: 80,),
          
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  
                  children: [
          
                    _modeButtons(),
                    
                    SizedBox(height: 25,),
                
                    _pomoTimerWidget(),
                
                    SizedBox(height: 25,),
          
                    _tasksWidget(),
          
                    SizedBox(height: 15,),
          
                    //_footerWidget()
                  ],
                ),
              ],
            ),
          ),
        );
  }

  Container _tasksWidget() {
    return Container(
      width: 340,
      height: 300,
      decoration: BoxDecoration(
        color: Color(0xff252525),
        border: Border.all(
          width: 5,
          color: Color(0xff2C2C2C),
        ),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Text(
            'Tarefas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          Container(
            width: 300,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20)
            ),
          ),

          Expanded(
            child: Container(
              height: 174.5,
              clipBehavior: Clip.hardEdge,
            
              decoration: BoxDecoration(
                //color: Colors.green,
                borderRadius: BorderRadius.circular(20)
              ),
            
              child: ListView.separated(
                padding: EdgeInsets.all(10),
                itemCount: _taskManager.getTasks().length + 1,
                separatorBuilder: (context, index) => SizedBox(height: 15,),
                itemBuilder: (context, index) {
                  
                  if (index == 0) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
            
                        onTap: () {
                          setState(() {

                            toEditTask = TaskModel.empty;
                            toEditTaskIdx = -1;
                            toEdit = false;
                            _showEditTask = true;
                          });
                        },
            
                        child: DottedBorder(
                        
                          options: RoundedRectDottedBorderOptions(
                            color: Colors.white.withValues(alpha: 0.5),
                            strokeWidth: 2.5,
                            dashPattern: [10, 10],
                            strokeCap: StrokeCap.round,
                            radius: Radius.circular(20)
                          ),
                        
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                        
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                        
                                SvgPicture.asset(
                                  'assets/icons/plus.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.5), BlendMode.srcIn),
                                ),
                        
                                SizedBox(width: 10,),
                        
                                Text(
                                  'Nova Tarefa',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        ),
                      ),
                    );
                  }
            
                  TaskModel task = _taskManager.getTasks()[index - 1];
            
                  return Dismissible(
                    key: ValueKey(task.id),
                    direction: DismissDirection.horizontal,

                    onDismissed: (direction) {
                      setState(() {
                        _taskManager.removeTask(task);
                        _saveConfigs();
                      });
                    },

                    background: Container(
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20)
                      ),

                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: SvgPicture.asset(
                          'assets/icons/trashbin.svg',
                          width: 40,
                          height: 40,
                          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20)
                      ),

                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SvgPicture.asset(
                          'assets/icons/trashbin.svg',
                          width: 40,
                          height: 40,
                          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                    
                        onTap: () {
                          setState(() {
                            toEditTask = TaskModel(
                              title: task.title,
                              description: task.description,
                              cycles: task.cycles,
                              cyclesFinished: task.cyclesFinished,
                              isCompleted: task.isCompleted,
                            );
                            toEditTaskIdx = _taskManager.getTasks().indexOf(task);
                            toEdit = true;
                            _showEditTask = true;
                            //continue
                          });
                        },
                    
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Color(0xff2C2C2C),
                            borderRadius: BorderRadius.circular(20),
                          ),
                                    
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                            
                              children: [
                                
                                Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            
                                  children: [
                    
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        maxLines: 1,

                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                                          decorationColor: Colors.white,
                                          decorationThickness: 1.5,
                                        ),
                                      ),
                                    ),
                                    
                                    Container(
                                      height: 25,
                                      width: 25,
                                      color: Colors.transparent,
                                      child: Transform.scale(
                                        scale: 1.5,
                                        child: Checkbox(
                                          value: task.isCompleted,
                                        
                                          onChanged: (value) {
                                            setState(() {
                                              task.isCompleted = value ?? task.isCompleted;

                                              if (task.isCompleted) {
                                                _taskManager.sendTaskToEnd(task);
                                              }
                                            });
                                        
                                            _saveConfigs();
                                          },
                                        
                                          activeColor: Colors.white,
                                          checkColor: Colors.transparent,
                                          side: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadiusGeometry.circular(20)
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    
                                  children: [
                                    
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          //color: Colors.amber,
                                        ),
                                        child: Text(
                                          task.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Color(0xff636363),
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    Text(
                                      '${task.cyclesFinished}/${task.cycles}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Container _modeButtons() {
    return Container(
            height: 80,
            decoration: BoxDecoration(
              color: Color(0xff2C2C2C),
              borderRadius: BorderRadius.circular(20),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                //Pomodoro button
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton.icon(

                    iconAlignment: IconAlignment.start,
                    icon: SvgPicture.asset(
                      'assets/icons/tomato.svg',
                      height: 23,
                      width: 23,
                      colorFilter: ColorFilter.mode(Color(0xff2C2C2C), BlendMode.srcIn),
                      ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  
                    onPressed: () {
                      setState(() {
                        _playAudio('audio/button_press.wav');
                        _stopTimer();
                        _startIcon = _playIcon;
                        _setTimer(_pomoTime);
                        isPomo = true;
                        _bgColor = _pomoColor;
                      });
                    },
                  
                    label: Text(
                      'Pomodoro',
                      style: TextStyle(
                        color: Color(0xff2C2C2C),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),  
                      ),
                  ),
                ),

                SizedBox(width: 15,),

                //Break button
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton.icon(

                    iconAlignment: IconAlignment.end,
                    icon: SvgPicture.asset(
                      'assets/icons/break.svg',
                      height: 23,
                      width: 23,
                      colorFilter: ColorFilter.mode(Color(0xff2C2C2C), BlendMode.srcIn),
                      ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  
                    onPressed: () {
                      setState(() {
                        _playAudio('audio/button_press.wav');
                        _stopTimer();
                        _startIcon = _playIcon;
                        _setTimer(_breakTime);
                        isPomo = false;
                        _bgColor = _breakColor;
                      });
                    },
                  
                    label: Text(
                      'Descanso',
                      style: TextStyle(
                        color: Color(0xff2C2C2C),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),  
                      ),
                  ),
                )
              ],
            ),
          );
  }

  Container _pomoTimerWidget() {
    return Container(
      width: 340,
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(0xff2C2C2C),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          Padding(
            padding: EdgeInsets.only(left: 12.0, right: 12.0),
            child: LinearProgressIndicator(
              value: _timerProgress,
              backgroundColor: Color(0xff636363),
              color: Colors.white,
              minHeight: 5,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          Text(
            _formatedTime,
            style: TextStyle(
              height: 1.2,
              //backgroundColor: Colors.green,
              color: Colors.white,
              fontSize: 90,
              fontWeight: FontWeight.bold,
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              if (!_timerRunning)
              SizedBox(
                width: 300,
                height: 60,
                child: ElevatedButton(
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                
                  onPressed: () {

                    setState(() {
                      _startIcon = _pauseIcon;
                      _playAudio('audio/start_pomodoro.wav');
                      _startTimer();
                      });
                  },
          
                  child: SvgPicture.asset(
                  _playIcon,
                  height: 40,
                  width: 40,
                  colorFilter: ColorFilter.mode(Color(0xff2C2C2C), BlendMode.srcIn),
                  ),
                ),
              ),

              if (_timerRunning)
              SizedBox(
                width: 150,
                height: 60,
                child: ElevatedButton(
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                
                  onPressed: () {

                    setState(() {
                      _playAudio('audio/button_press.wav');

                      if (_pomoTimer?.isActive ?? false) {
                        _startIcon = _playIcon;
                        _pauseTimer();
                      }

                      else {
                        _startIcon = _pauseIcon;
                        _playAudio('audio/start_pomodoro.wav');
                        _startTimer();
                      }
                    });
                  },
          
                  child: SvgPicture.asset(
                  _startIcon,
                  height: 40,
                  width: 40,
                  colorFilter: ColorFilter.mode(Color(0xff2C2C2C), BlendMode.srcIn),
                  ),
                ),
              ),

              if (_timerRunning)
              SizedBox(width: 10,),

              if (_timerRunning)
              SizedBox(
                width: 150,
                height: 60,
                child: ElevatedButton(
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                
                  onPressed: () {
                    setState(() {
                      _playAudio('audio/button_press.wav');
                      _startIcon = _pauseIcon;
                      _stopTimer();
                    });
                  },
          
                  child: SvgPicture.asset(
                  'assets/icons/stop.svg',
                  height: 40,
                  width: 40,
                  colorFilter: ColorFilter.mode(Color(0xff2C2C2C), BlendMode.srcIn),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,

      title: Text(
        'CICLO FOCO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w900
        ),
      ),

      actions: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),

            onTap: () {
              setState(() {
                _showConfigs = true;
              });
            },
        
            child: Container(
              width: 50,
              height: 50,
            
              decoration: BoxDecoration(
                //color: Color(0xff2C2C2C),
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
            
              child: SvgPicture.asset(
                'assets/icons/cog.svg',
                width: 50,
                height: 50,
                colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        )
      ],
    );
  }

  @override
  void dispose() {
    _pomoTimer?.cancel(); // stop the timer when widget is destroyed
    super.dispose();
  }
}

//New task overlay
class newTaskScreen extends StatefulWidget {

  final _MyHomeState home;
  final String title;
  final String description;
  final int cycles;
  final int cyclesFinished;
  final bool toEdit;
  final int editTaskIdx;

  const newTaskScreen({
    super.key,
    required this.home,
    required this.title,
    required this.description,
    required this.cycles,
    required this.cyclesFinished,
    required this.toEdit,
    required this.editTaskIdx,
  });

  @override
  State<newTaskScreen> createState() => _newTaskScreenState();
}

class _newTaskScreenState extends State<newTaskScreen> {

  late TextEditingController titleController;
  late TextEditingController descController;
  late TextEditingController cyclesController;
  
  late String _taskTitle = '';
  late String _taskDesc = '';
  late int _taskCycles = widget.cycles; 

  bool _canSave = false;
  bool _showDesc = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.title,
    );

    descController = TextEditingController(
      text: widget.description,
    );

    cyclesController = TextEditingController(
      text: widget.cycles.toString(),
    );

    if (widget.toEdit) {
      _taskTitle = widget.title;
      _taskDesc = widget.description;
      _taskCycles = widget.cycles;
    }

    if (widget.description != '') {
      _showDesc = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.home.setState(() {
                widget.home._showEditTask = false;
              });
            },
          
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),

        Material(
          color: Colors.transparent,

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),

            child: Center(
              child: Container(

                decoration: BoxDecoration(
                  color: Color(0xff2C2C2C),
                  borderRadius: BorderRadius.circular(20)
                ),
              
                child: ConstrainedBox(
                  
                  constraints: BoxConstraints(
                    maxHeight: 300,
                    minHeight: 150,
                  ),
              
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        //Row 1
                        Row(
                          children: [
                            
                            Expanded(
                              child: TextField(
                                controller: titleController,
                                keyboardType: TextInputType.multiline,

                                onChanged: (value) {
                                  _taskTitle = value;

                                  setState(() {
                                      if (value == "") {
                                      _canSave = false;
                                    }

                                    else {
                                      _canSave = true;
                                    }
                                  });
                                },

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold
                                ),
                                                      
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(borderSide: BorderSide.none),
                                  hint: Text(
                                    'Título da Tarefa',
                                    
                                    style: TextStyle(
                                      color: Color(0xff636363),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                   filled: true,
                                   fillColor: Colors.transparent,
                                )
                              ),
                            ),
                        
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  
                                  widget.home.setState(() {
                                    
                                    if (widget.home.toEditTask.cyclesFinished > _taskCycles) {
                                      widget.home.toEditTask.cyclesFinished = _taskCycles;
                                    }

                                    if (widget.toEdit) {
                                      widget.home._taskManager.editTask(
                                        widget.editTaskIdx,
                                        
                                        TaskModel( 
                                        title: _taskTitle,
                                        description: _taskDesc,
                                        cycles: _taskCycles,
                                        cyclesFinished: widget.home.toEditTask.cyclesFinished,
                                        isCompleted: widget.home.toEditTask.isCompleted,
                                      ));
                                    }

                                    else if (_taskTitle != '') {
                                      widget.home._taskManager.addTask(TaskModel(
                                        title: _taskTitle,
                                        description: _taskDesc,
                                        cycles: _taskCycles,
                                        cyclesFinished: 0,
                                        isCompleted: false,
                                      ));
                                    }

                                    if (_taskTitle == '' && widget.toEdit) {
                                      return;
                                    }

                                    widget.home._showEditTask = false;
                                    widget.home._saveConfigs();
                                  });
                                },
                            
                                borderRadius: BorderRadius.circular(100),
                            
                                child: Container(
                                  width: 40,
                                  height: 40,
                                
                                  decoration: BoxDecoration(
                                    color: Colors.transparent ,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                
                                  child: Column(
                                    children: [
                                      Visibility(
                                        visible: !_canSave,
                                        child: SvgPicture.asset(
                                          'assets/icons/close.svg',
                                          width: 40,
                                          height: 40,
                                          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                        ),
                                      ),

                                      Visibility(
                                        visible: _canSave,
                                        child: RotatedBox(
                                          quarterTurns: 1,
                                          child: SvgPicture.asset(
                                            'assets/icons/arrow.svg',
                                            width: 30,
                                            height: 30,
                                            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Visibility(
                          visible: _showDesc,

                          child: TextField(
                            controller: descController,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 3,
                          
                            onChanged: (value) {
                              _taskDesc = value;
                            },
                          
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold
                            ),
                                                  
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(borderSide: BorderSide.none),
                              hint: Text(
                                'Descrição...',
                                
                                style: TextStyle(
                                  color: Color(0xff636363),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                                filled: true,
                                fillColor: Colors.transparent,
                            )
                          ),
                        ),

                        Visibility(
                          visible: !_showDesc,
                          child: Material(
                            color: Colors.transparent,
                          
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showDesc = true;
                                });
                              },
                          
                              child: Text(
                                '+ Adicionar descrição...',
                                
                                style: TextStyle(
                                  backgroundColor: Colors.transparent,
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 30,),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      int textInt = int.parse(cyclesController.text);

                                      if (textInt > 1) {
                                        cyclesController.text = (textInt - 1).toString();

                                        _taskCycles--;
                                      }
                                    });
                                  },
                                  
                                  borderRadius: BorderRadius.circular(100),

                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: Column(
                                          children: [
                                            
                                            SvgPicture.asset(
                                              'assets/icons/arrow.svg',
                                              width: 30,
                                              height: 30,
                                              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: 10,),

                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: cyclesController,
                                  textAlign: TextAlign.center,
                                  textAlignVertical: TextAlignVertical.center,
                                  keyboardType: TextInputType.number,

                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],

                                  onChanged: (value) {
                                    int intValue = int.parse(value);

                                    if (value.isEmpty) {
                                      _taskCycles = 1;
                                    }

                                    else if (intValue > 999) {
                                      _taskCycles = 999;
                                    }

                                    else if (intValue < 1) {
                                      _taskCycles = 1;
                                    }

                                    else if (intValue >= 1 && intValue <= 999) {
                                      _taskCycles = intValue;
                                    }
                                    
                                    cyclesController.text = _taskCycles.toString();
                                  },

                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold
                                  ),
                                                        
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    
                                    hint: Text(
                                      'Ciclos',
                                      
                                      style: TextStyle(
                                        color: Color(0xff636363),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                      filled: true,
                                      fillColor: Color(0xff636363),
                                  )
                                ),
                              ),

                              SizedBox(width: 10,),

                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      int textInt = int.parse(cyclesController.text);

                                      if (textInt < 999) {
                                        cyclesController.text = ( textInt + 1).toString();
                                        _taskCycles++;
                                      }
                                    });
                                  },
                                  
                                  borderRadius: BorderRadius.circular(100),

                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: RotatedBox(
                                        quarterTurns: 1,
                                        child: SvgPicture.asset(
                                          'assets/icons/arrow.svg',
                                          width: 30,
                                          height: 30,
                                          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}

//Configurations Overlay
class ConfigsOverlay extends StatefulWidget {

  final _MyHomeState home;

  const ConfigsOverlay({
    super.key,
    required this.home,
  });

  @override
  State<ConfigsOverlay> createState() => _ConfigsOverlayState();
}

class _ConfigsOverlayState extends State<ConfigsOverlay> {

  late TextEditingController pomoController;
  late TextEditingController breakController;

  @override 
  void initState() {
    super.initState();

    pomoController = TextEditingController(
      text: widget.home._pomoTime.toString(),
    );

    breakController = TextEditingController(
      text: widget.home._breakTime.toString(),
    );
  }

  @override
  void dispose() {
    pomoController.dispose();
    breakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      
      children: [
        
        GestureDetector(
          onTap: () {
            widget.home.setState(() {
              widget.home._showConfigs = false;
            });
          },

          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
        
        Positioned(
        right: 20,
        bottom: 20,
        left: 20,
        top: 40,
        
        child: Material(
          color: Colors.transparent,
      
          child: Container(
            width: 340,
            padding: EdgeInsets.only(top: 20, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          
            child: Column(
              children: [
                Text(
                  'Configurações',
                  style: TextStyle(
                    height: 1,
                    color: Color(0xff2C2C2C),
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
      
                Padding(
                  padding: const EdgeInsets.only(left: 18, right: 18),
                  child: Divider(
                    color: Color(0xffE6E6E6),
                    thickness: 2.5,
                  ),
                ),
      
                Expanded(
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: ListView(
                      padding: EdgeInsets.all(0),
                      children: [

                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                          ),

                          child: Column(
                            children: [

                            Text(
                              'Timers',
                              style: TextStyle(
                                color: Color(0xff2C2C2C),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            SizedBox(height: 8,),
                            
                            //Pomodoro TextField
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  
                                  Text(
                                  'Pomodoro',
                                  style: TextStyle(
                                    color: Color(0xffACACAC),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              
                                  SizedBox(
                                    width: 150,
                                    height: 50,
                            
                                    child: TextField(
                                      controller: pomoController,
                                      onChanged: (value) {
                                        int newPomoTime = int.parse(value);
                            
                                        //Clamps value between 1 and 999
                                        if (newPomoTime > 999) {
                                          newPomoTime = 999;   
                                        } else if (newPomoTime < 1) {
                                          newPomoTime = 1;
                                        }
                            
                                        //Sets TextField's text to clampped number
                                        pomoController.text = '$newPomoTime';
                                        pomoController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: pomoController.text.length),
                                        );
                            
                                        //Sets timer if timer not running
                                        if (widget.home.isPomo && widget.home._timerRunning == false) {
                                          widget.home.setState(() {
                                            widget.home._setTimer(newPomoTime);
                                          });
                                        }
                                        widget.home._currentTime = newPomoTime;
                                        widget.home._pomoTime = newPomoTime;
                                        widget.home._saveConfigs();
                                      },
                            
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                            
                                      style: TextStyle(
                                        color: Color(0xff2C2C2C),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                            
                                      textAlign: TextAlign.center,
                                      textAlignVertical: TextAlignVertical.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: Colors.transparent),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: Colors.transparent),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: Colors.transparent),
                                        ),
                                        
                                        contentPadding: EdgeInsets.all(0),
                                        hintText: '25',
                                        hintStyle: TextStyle(
                                          color: Color(0xffACACAC),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        filled: true,
                                        fillColor: Color(0xffE6E6E6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 20,),
                            
                            //Break TextField
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  
                                  Text(
                                  'Descanso',
                                  style: TextStyle(
                                    color: Color(0xffACACAC),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              
                                  SizedBox(
                                    width: 150,
                                    height: 50,
                            
                                    child: TextField(
                                      controller: breakController,
                                      onChanged: (value) {
                                        int newBreakTime = int.parse(value);
                            
                                        //Clamps value between 1 and 999
                                        if (newBreakTime > 999) {
                                          newBreakTime = 999;   
                                        } else if (newBreakTime < 1) {
                                          newBreakTime = 1;
                                        }
                            
                                        //Sets textfield's text to clampped number
                                        breakController.text = '$newBreakTime';
                                        breakController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: breakController.text.length),
                                        );
                            
                                        //Changes InApp timer if it's selected and not running
                                        if (!widget.home.isPomo && widget.home._timerRunning == false) {
                                          widget.home.setState(() {
                                            widget.home._setTimer(newBreakTime);
                                          });
                                        }
                            
                                        widget.home._currentTime = newBreakTime;
                                        widget.home._breakTime = newBreakTime;
                                        widget.home._saveConfigs();                                              
                                      },
                            
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                            
                                      style: TextStyle(
                                        color: Color(0xff2C2C2C),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                            
                                      textAlign: TextAlign.center,
                                      textAlignVertical: TextAlignVertical.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: Colors.transparent),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: Colors.transparent),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide(color: Colors.transparent),
                                        ),
                                        
                                        contentPadding: EdgeInsets.all(0),
                                        hintText: '5',
                                        hintStyle: TextStyle(
                                          color: Color(0xffACACAC),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        filled: true,
                                        fillColor: Color(0xffE6E6E6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                                                            
                            SizedBox(height: 20,),
                            
                            //AutoStart Switch
                            StatefulBuilder(
                              builder: (context, setState) => Padding(
                            
                                padding: const EdgeInsets.only(left: 16, right: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    
                                    Text(
                                    'Auto Início',
                                    style: TextStyle(
                                      color: Color(0xffACACAC),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                
                                    Transform.scale(
                                      scale: 1.5,
                                      child: Switch(
                                        value: widget.home._autoStartTimersOn,
                                                                          
                                        onChanged: (value) {
                                          widget.home.setState(() {
                                            widget.home._autoStartTimersOn = value;
                                            widget.home._saveConfigs();
                                          });
                                        },
                                        
                                        activeThumbColor: Colors.white,
                                        activeTrackColor: widget.home._breakColor,
                                        inactiveTrackColor: widget.home._pomoColor,
                                        inactiveThumbColor: Colors.white,
                                      
                                        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ]
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                          child: Divider(
                            color: Color(0xffE6E6E6),
                            thickness: 2.5,
                          ),
                        ),

                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                          ),

                          child: Column(
                            children: [

                            Text(
                              'Alarmes',
                              style: TextStyle(
                                color: Color(0xff2C2C2C),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            SizedBox(height: 8,),
                            
                            //AutoStart Switch
                            StatefulBuilder(
                              builder: (context, setState) => Padding(
                            
                                padding: const EdgeInsets.only(left: 16, right: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    
                                    Text(
                                    'Tocar Alarmes',
                                    style: TextStyle(
                                      color: Color(0xffACACAC),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                
                                    Transform.scale(
                                      scale: 1.5,
                                      child: Switch(
                                        value: widget.home._playAlarmsOn,
                                                                          
                                        onChanged: (value) {
                                          setState(() {
                                            widget.home._playAlarmsOn = value;
                                            widget.home._saveConfigs();
                                          });
                                        },
                                        
                                        activeThumbColor: Colors.white,
                                        activeTrackColor: widget.home._breakColor,
                                        inactiveTrackColor: widget.home._pomoColor,
                                        inactiveThumbColor: Colors.white,
                                      
                                        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 20,),

                            //Pomodoro Dropdown
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  
                                  Text(
                                  'Pomodoro',
                                  style: TextStyle(
                                    color: Color(0xffACACAC),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  DropdownMenu(
                                    width: 150,
                                    initialSelection: widget.home._pomoAlarm,
                                    
                                    onSelected: (value) {

                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                            widget.home._playAudio(widget.home.alarms[value]);
                                        });
                                        widget.home._pomoAlarm = value ?? widget.home._pomoAlarm;
                                        widget.home._saveConfigs();
                                    }, 

                                    menuHeight: 250,

                                    trailingIcon: RotatedBox(
                                      quarterTurns: 2,
                                      child: SvgPicture.asset('assets/icons/arrow.svg'),
                                      ),
                                    
                                    selectedTrailingIcon: RotatedBox(
                                      quarterTurns: 0,
                                      child: SvgPicture.asset('assets/icons/arrow.svg'),
                                    ),

                                    label: const Text(
                                      'Som',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        color: Color(0xff2C2C2C),
                                      ),
                                    ),
                                  
                                    textStyle: TextStyle(
                                      color: Color(0xff2C2C2C),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  
                                    inputDecorationTheme: InputDecorationTheme(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.only(top: 2, bottom: 2, left: 8),
                                      filled: true,
                                      fillColor: Color(0xffE6E6E6),
                                      
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide.none,
                                      )
                                    ),
                                  
                                    menuStyle: MenuStyle(
                                      elevation: WidgetStatePropertyAll(0.0),
                                      backgroundColor: WidgetStatePropertyAll(Color(0xffE6E6E6)),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadiusGeometry.circular(20)
                                        )
                                      )
                                    ),
                                  
                                    dropdownMenuEntries: const [
                                      DropdownMenuEntry(value: '1', label: 'Alarm'),
                                      DropdownMenuEntry(value: '2', label: 'Birds'),
                                      DropdownMenuEntry(value: '3', label: 'Error'),
                                      DropdownMenuEntry(value: '4', label: 'Soft Synth'),
                                      DropdownMenuEntry(value: '5', label: 'Wind Chimes'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 20,),
                                                            
                            //Pomodoro Dropdown
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  
                                  Text(
                                  'Descanso',
                                  style: TextStyle(
                                    color: Color(0xffACACAC),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                                                  
                                  DropdownMenu(
                                    width: 150,
                                    initialSelection: widget.home._breakAlarm,
                                    
                                    onSelected: (value) {
                                                                  
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                            widget.home._playAudio(widget.home.alarms[value]);
                                        });
                                        widget.home._breakAlarm = value ?? widget.home._breakAlarm;
                                        widget.home._saveConfigs();
                                    }, 
                                                                  
                                    menuHeight: 250,
                                  
                                    trailingIcon: RotatedBox(
                                      quarterTurns: 2,
                                      child: SvgPicture.asset('assets/icons/arrow.svg'),
                                      ),
                                    
                                    selectedTrailingIcon: RotatedBox(
                                      quarterTurns: 0,
                                      child: SvgPicture.asset('assets/icons/arrow.svg'),
                                    ),

                                    label: const Text(
                                      'Som',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        color: Color(0xff2C2C2C),
                                      ),
                                    ),
                                  
                                    textStyle: TextStyle(
                                      color: Color(0xff2C2C2C),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  
                                    inputDecorationTheme: InputDecorationTheme(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.only(top: 2, bottom: 2, left: 8),
                                      filled: true,
                                      fillColor: Color(0xffE6E6E6),
                                      
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide.none,
                                      )
                                    ),
                                  
                                    menuStyle: MenuStyle(
                                      elevation: WidgetStatePropertyAll(0.0),
                                      backgroundColor: WidgetStatePropertyAll(Color(0xffE6E6E6)),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadiusGeometry.circular(20)
                                        )
                                      )
                                    ),
                                  
                                    dropdownMenuEntries: const [
                                      DropdownMenuEntry(value: '1', label: 'Alarm'),
                                      DropdownMenuEntry(value: '2', label: 'Birds'),
                                      DropdownMenuEntry(value: '3', label: 'Error'),
                                      DropdownMenuEntry(value: '4', label: 'Soft Synth'),
                                      DropdownMenuEntry(value: '5', label: 'Wind Chimes'),
                                    ],
                                  ),
                                  ],
                                ),
                            ),
                          ]
                          ),
                        )
                      ]  
                    ),
                  ),
                ),
      
                SizedBox(height: 10,),
      
                ElevatedButton(
                  onPressed: () {
                    widget.home.setState(() {
                      widget.home._showConfigs = false;
                    });
                  },
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xffE6E6E6),
                    elevation: 0.0,
                    shadowColor: Colors.transparent,
      
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(20),
                    ),
      
                    minimumSize: Size(
                      150,60
                    )
                  ),
      
                  child: Text(
                    'Voltar',
                    style: TextStyle(
                      height: 1,
                      color: Color(0xff2C2C2C),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      ]
    );
  }

}