import 'package:audioplayers/audioplayers.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pomodoro_timer/models/task_model.dart';
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
  
  late OverlayEntry entry;
  
  late TaskModel _taskManager;
  List<TaskModel> _tasksList = [];

  String _formatedTime = '00:00';
  String _startIcon = '';
  final String _playIcon = 'assets/icons/play.svg';
  final String _pauseIcon = 'assets/icons/pause.svg';

  bool _autoStartTimersOn = false;
  bool _timerRunning = false;

  Timer? _pomoTimer;

  int _pomoTime = 25;
  int _breakTime = 5;
  int _currentTime = 0;
  int _timer = 0;

  double _timerProgress = 0;

  final Color _breakColor = Color.fromARGB(255, 55, 154, 247);
  final Color _pomoColor = Color(0xffF7374F);
  Color _bgColor = Color(0xffF7374F);
  
  AudioPlayer? _audioPlayer;

  @override
  void initState() {

    super.initState();

    _taskManager = TaskModel(
      title: '',
      description: '',
      cycles: 0,
      cyclesFinished: 0,
    );

    TaskModel task1 = _taskManager.fromMap(
      {
        'title': 'Estudar',
        'description': 'Páginas 20 à 25',
        'cycles': 2,
        'cyclesfinished': 0,
      }
    );

    _taskManager.addTask(task1);

    _tasksList = _taskManager.getTasks();

    _audioPlayer = AudioPlayer();
    _startIcon = _playIcon;
    _currentTime = _pomoTime;
    _timer = _currentTime;
    _bgColor = _pomoColor;
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
          _playAudio('audio/end_pomodoro.wav');
          _startIcon = _playIcon;

          //Swaps pomodoro to break
          if (_currentTime == _pomoTime) {
            _bgColor = _breakColor;
            _setTimer(_breakTime);
          } 
          
          //Swaps break to pomodoro
          else {
            _bgColor = _pomoColor;
            _setTimer(_pomoTime);
          }

          //Starts timer automatically
          if (_autoStartTimersOn) _startTimer();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {  

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
              fontWeight: FontWeight.bold
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
                itemCount: _tasksList.length + 1,
                separatorBuilder: (context, index) => SizedBox(height: 15,),
                itemBuilder: (context, index) {
                  
                  if (index == 0) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
            
                        onTap: () {
                          setState(() {
                            _taskManager.addTask(
                              TaskModel(title: 'title', description: 'description', cycles: 1, cyclesFinished: 0)
                            );
            
                            _tasksList = _taskManager.getTasks();
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
            
                  TaskModel task = _tasksList[index - 1];
            
                  return Container(
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
                      
                              Text(
                                task.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              
                              SizedBox(
                                width: 30,
                                height: 30,
                                child: SvgPicture.asset(
                                    'assets/icons/edit.svg',
                                    height: 30,
                                    width: 30,
                                    colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                              )
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
              _showConfigs();
            },
        
            child: Container(
              width: 50,
              height: 50,
            
              decoration: BoxDecoration(
                color: Color(0xff2C2C2C),
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

  void _showConfigs() {

    //Loading configs into UI
    final pomoController = TextEditingController(
      text: _pomoTime.toString(),
    );
    final breakController = TextEditingController(
      text: _breakTime.toString(),
    );

    bool autoStartOn = _autoStartTimersOn;

    entry = OverlayEntry(
      builder: (context) {

        return Stack(
          
          children: [
            
            GestureDetector(
              onTap: () {
                _closeConfigs();
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
                              height: 240,
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
                                              if (_currentTime == _pomoTime && _timerRunning == false) {
                                                setState(() {
                                                  _setTimer(newPomoTime);
                                                });
                                              }
                                              _currentTime = newPomoTime;
                                              _pomoTime = newPomoTime;
                                              
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
                                              if (_currentTime == _breakTime && _timerRunning == false) {
                                                setState(() {
                                                  _setTimer(newBreakTime);
                                                });
                                              }

                                              _currentTime = newBreakTime;
                                              _breakTime = newBreakTime;
                                              
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
                                              hintText: 'Minutos...',
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
                                              value: autoStartOn,
                                                                                
                                              onChanged: (value) {
                                                setState(() {
                                                  autoStartOn = value;
                                                  _autoStartTimersOn = autoStartOn;
                                                });
                                              },
                                              
                                              activeThumbColor: Colors.white,
                                              activeTrackColor: _breakColor,
                                              inactiveTrackColor: _pomoColor,
                                              inactiveThumbColor: Colors.white,
                                            
                                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                                            ),
                                          )
                                        ],
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
          
                    SizedBox(height: 10,),
          
                    ElevatedButton(
                      onPressed: () {
                        _closeConfigs();
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
      },
    );

    final overlay = Overlay.of(context);
    overlay.insert(entry);

  }

  void _closeConfigs() {
    // ignore: unnecessary_null_comparison
    if (entry != null) {
      entry.remove();
    }
  }

  @override
  void dispose() {
    _pomoTimer?.cancel(); // stop the timer when widget is destroyed
    super.dispose();
  }
}