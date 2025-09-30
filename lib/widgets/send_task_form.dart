// lib/widgets/send_task_form.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../models/medication.dart';
import '../models/task_request_model.dart';
import '../providers/task_request_provider.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/medication_service.dart';
import 'glass_container.dart';

enum ScheduleType { once, nTimes, interval, mealBased, bedtime }
enum MealRelation { before, after }

class _TaskState {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController durationController;
  bool isMedication;
  DateTime startDate;
  ScheduleType scheduleType;
  TimeOfDay onceTime;
  int nTimesCount;
  bool isNTimesStrict;
  List<TimeOfDay> strictTimes;
  int nTimesInterval;
  TimeOfDay nTimesStartTime;
  int intervalHours;
  TimeOfDay intervalStartTime;
  MealRelation mealRelation;
  Set<String> selectedMeals;
  Medication? selectedMedication;

  _TaskState()
      : nameController = TextEditingController(),
        descriptionController = TextEditingController(),
        durationController = TextEditingController(),
        isMedication = false,
        startDate = DateTime.now(),
        scheduleType = ScheduleType.once,
        onceTime = const TimeOfDay(hour: 9, minute: 0),
        nTimesCount = 2,
        isNTimesStrict = true,
        strictTimes = [const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 21, minute: 0)],
        nTimesInterval = 6,
        nTimesStartTime = const TimeOfDay(hour: 8, minute: 0),
        intervalHours = 2,
        intervalStartTime = const TimeOfDay(hour: 8, minute: 0),
        mealRelation = MealRelation.after,
        selectedMeals = {'breakfast', 'dinner'},
        selectedMedication = null;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    durationController.dispose();
  }
  
  factory _TaskState.fromParsedJson(Map<String, dynamic> json) {
    final state = _TaskState();
    state.isMedication = json['isMedication'] ?? false;
    state.nameController.text = json['medicationName'] ?? '';
    state.descriptionController.text = json['description'] ?? '';
    state.durationController.text = json['duration'] ?? '';
    
    final scheduleTypeString = json['scheduleType'] as String?;
    switch (scheduleTypeString) {
      case 'nTimes':
        state.scheduleType = ScheduleType.nTimes;
        state.isNTimesStrict = json['isNTimesStrict'] ?? true;
        state.nTimesCount = json['nTimesCount'] ?? 2;
        if (json['strictTimes'] != null && json['strictTimes'] is List) {
          state.strictTimes = (json['strictTimes'] as List).map((t) {
            final parts = t.toString().split(':');
            return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }).toList();
        }
        break;
      case 'mealBased':
        state.scheduleType = ScheduleType.mealBased;
        final relationString = json['mealRelation'] as String?;
        state.mealRelation = relationString == 'before' ? MealRelation.before : MealRelation.after;
        if (json['selectedMeals'] != null && json['selectedMeals'] is List) {
          state.selectedMeals = (json['selectedMeals'] as List).map((m) => m.toString()).toSet();
        }
        break;
      default:
        state.scheduleType = ScheduleType.once;
        break;
    }
    return state;
  }

  factory _TaskState.fromTaskRequest(TaskRequest request) {
    final state = _TaskState();
    final taskData = request.taskData;
    
    state.isMedication = request.taskType == 'medication';
    state.nameController.text = taskData['name'] ?? '';
    state.descriptionController.text = taskData['description'] ?? '';

    if (taskData['start_date'] != null) {
      state.startDate = DateTime.tryParse(taskData['start_date']) ?? DateTime.now();
    }
    
    final rules = taskData['rules'] as List?;
    if (rules != null && rules.isNotEmpty) {
      final rule = rules.first as Map<String, dynamic>;
      state.durationController.text = rule['duration_days']?.toString() ?? '';
      
      final ruleTypeString = rule['rule_type'] as String?;
      switch(ruleTypeString) {
         case 'once':
          state.scheduleType = ScheduleType.once;
          if (rule['start_time'] != null) {
            final parts = rule['start_time'].split(':');
            state.onceTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          break;
      }
    }
    return state;
  }
}


class SendTaskForm extends StatefulWidget {
  final TaskRequest? requestToEdit;
  const SendTaskForm({super.key, this.requestToEdit});

  @override
  State<SendTaskForm> createState() => _SendTaskFormState();
}

class _SendTaskFormState extends State<SendTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final ChatService _chatService = ChatService();
  final MedicationService _medicationService = MedicationService();
  final _assigneeController = TextEditingController();
  ChatUser? _selectedAssignee;
  Timer? _debounce;
  List<_TaskState> _tasks = [_TaskState()];
  int _currentTaskIndex = 0;
  _TaskState get _currentTask => _tasks[_currentTaskIndex];
  bool _isSubmitting = false;
  bool get _isEditMode => widget.requestToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.requestToEdit != null) {
      final request = widget.requestToEdit!;
      _selectedAssignee = ChatUser(uuid: request.partnerUuid, username: '', displayName: request.partnerDisplayName);
      _assigneeController.text = request.partnerDisplayName;
      _tasks = [_TaskState.fromTaskRequest(request)];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (var task in _tasks) {
      task.dispose();
    }
    _assigneeController.dispose();
    super.dispose();
  }
  
  String _formatTimeOfDay(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedAssignee = null;
      _assigneeController.clear();
      for (var task in _tasks) {
        task.dispose();
      }
      _tasks = [_TaskState()];
      _currentTaskIndex = 0;
    });
  }

  void _addNewTask() {
    setState(() {
      _tasks.add(_TaskState());
      _currentTaskIndex = _tasks.length - 1;
    });
  }
  
  void _removeTask(int index) {
    if (_tasks.length <= 1) return;
    setState(() {
      _tasks.removeAt(index).dispose();
      if (_currentTaskIndex >= index) {
        _currentTaskIndex = (_currentTaskIndex - 1).clamp(0, _tasks.length - 1);
      }
    });
  }

  void _parsePrescription() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null) return;
    setState(() => _isSubmitting = true);
    final provider = Provider.of<TaskRequestProvider>(context, listen: false);
    final Uint8List imageBytes = await image.readAsBytes();
    final String filename = image.name;
    try {
      final parsedTasksData = await provider.parsePrescription(imageBytes, filename);
      if (parsedTasksData != null && parsedTasksData.isNotEmpty) {
        setState(() {
          for (var task in _tasks) { task.dispose(); }
          _tasks = parsedTasksData.map((taskData) => _TaskState.fromParsedJson(taskData)).toList();
          _currentTaskIndex = 0;
          if (_selectedAssignee != null) {
            _assigneeController.text = _selectedAssignee!.displayName;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Prescription imported successfully!'),
          backgroundColor: Colors.green,
        ));
      } else {
        throw Exception("No tasks were parsed from the prescription.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error parsing prescription: ${provider.errorMessage ?? e.toString()}'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

    Map<String, dynamic> _buildTaskPayload(_TaskState task) {
    Map<String, dynamic> taskData = {
      'name': task.nameController.text.trim(),
      'description': task.descriptionController.text.trim(),
      'start_date': _formatDate(task.startDate),
      'rules': [],
    };
    if(task.isMedication && task.selectedMedication != null) {
        taskData['medication_id'] = task.selectedMedication!.id;
    } else if (task.isMedication && task.selectedMedication == null) {
        taskData['medication_id'] = -1;
    }
    
    Map<String, dynamic> rule = {};
    switch (task.scheduleType) {
      case ScheduleType.once:
        rule['rule_type'] = 'once';
        rule['start_time'] = _formatTimeOfDay(task.onceTime);
        break;
      case ScheduleType.nTimes:
        rule['rule_type'] = 'n_times';
        rule['count'] = task.nTimesCount;
        if (task.isNTimesStrict) { 
          rule['extras'] = jsonEncode({'strict_times': task.strictTimes.map((t) => _formatTimeOfDay(t)).toList()}); 
        } else {
          rule['interval_hours'] = task.nTimesInterval;
          rule['start_time'] = _formatTimeOfDay(task.nTimesStartTime);
        }
        break;
      case ScheduleType.interval:
        rule['rule_type'] = 'interval';
        rule['interval_hours'] = task.intervalHours;
        rule['start_time'] = _formatTimeOfDay(task.intervalStartTime);
        break;
      case ScheduleType.mealBased:
        rule['rule_type'] = 'meal_based';
        rule['extras'] = jsonEncode({'relation': task.mealRelation.toString().split('.').last, 'meals': task.selectedMeals.toList()});
        break;
      case ScheduleType.bedtime:
        rule['rule_type'] = 'bedtime';
        break;
    }

    if (task.durationController.text.isNotEmpty) {
      rule['duration_days'] = int.tryParse(task.durationController.text);
    }
    (taskData['rules'] as List).add(rule);
    return taskData;
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedAssignee == null) {
      if (_selectedAssignee == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select an assignee.'),
          backgroundColor: Colors.amber,
        ));
      }
      return;
    }
    for (var task in _tasks) {
      if (task.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Task ${ _tasks.indexOf(task) + 1} needs a name.'),
          backgroundColor: Colors.amber,
        ));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final requestProvider = Provider.of<TaskRequestProvider>(context, listen: false);
    final senderUuid = userProvider.userUuid;
    if (senderUuid == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Sender not logged in.')));
        setState(() => _isSubmitting = false);
        return;
    }

    bool success;
    if (_isEditMode) {
      final taskPayload = _buildTaskPayload(_currentTask);
      success = await requestProvider.updateSentRequest(
        requestUuid: widget.requestToEdit!.requestUuid,
        actorUuid: senderUuid,
        taskData: taskPayload,
      );
    } else {
      final List<Map<String, dynamic>> tasksPayload = _tasks.map((task) {
        return {
          'task_type': task.isMedication ? 'medication' : 'task',
          'task_data': _buildTaskPayload(task),
        };
      }).toList();

      success = await requestProvider.sendMultipleRequests(
          senderUuid: senderUuid,
          assigneeUuid: _selectedAssignee!.uuid,
          tasks: tasksPayload,
      );
    }
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditMode ? 'Request updated!' : 'Request(s) sent!'),
          backgroundColor: Colors.green,
        ));
        
        if (_isEditMode) {
          Navigator.of(context).pop();
        } else {
          _resetForm();
        }
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(requestProvider.errorMessage ?? 'Operation failed.'),
          backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userRole = userProvider.userRole;
    final canSendNormalTask = userRole == UserRole.manager || userRole == UserRole.mixed;
    final canSendMedication = userRole == UserRole.doctor || userRole == UserRole.mixed;
    
    if(!_isEditMode) {
        if(canSendNormalTask && !canSendMedication) _currentTask.isMedication = false;
        if(!canSendNormalTask && canSendMedication) _currentTask.isMedication = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: KeyedSubtree(
        key: ValueKey<int>(_currentTaskIndex),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Assign To'),
              Row(
                children: [
                  Expanded(child: _buildFormContainer(child: _buildAssigneeSearch())),
                  const SizedBox(width: 8),
                  if (!_isEditMode)
                    _buildFormContainer(
                      child: IconButton(
                        icon: const Icon(Icons.document_scanner_outlined, color: Colors.white),
                        tooltip: 'Import from Prescription',
                        onPressed: _isSubmitting ? null : _parsePrescription,
                      ),
                    )
                ],
              ),
              const SizedBox(height: 24),
              _buildTaskSwitcher(),
              const SizedBox(height: 12),
              _buildSectionHeader('Task Details'),
              _buildFormContainer(child: _buildBasicInfoSection(canSendNormalTask, canSendMedication)),
              const SizedBox(height: 24),
              _buildSectionHeader('Schedule'),
              _buildFormContainer(child: _buildSchedulingSection()),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isEditMode ? 'Update Request' : 'Send ${_tasks.length} Task(s)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSwitcher() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...List.generate(_tasks.length, (index) {
            final isSelected = _currentTaskIndex == index;
            return GestureDetector(
              onDoubleTap: () => _removeTask(index),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(_tasks[index].nameController.text.isNotEmpty 
                      ? _tasks[index].nameController.text 
                      : "Task ${(index + 1)}"),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  selected: isSelected,
                  backgroundColor: Colors.blueGrey.shade100, 
                  selectedColor: Theme.of(context).primaryColor,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentTaskIndex = index);
                  },
                ),
              ),
            );
          }),
          if (!_isEditMode)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: ActionChip(
                avatar: Icon(Icons.add, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                label: Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                onPressed: _addNewTask,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAssigneeSearch() {
     return Autocomplete<ChatUser>(
      initialValue: TextEditingValue(text: _assigneeController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<ChatUser>.empty();
        }
        final completer = Completer<Iterable<ChatUser>>();
        final actorUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () async {
          if (actorUuid != null) {
            try {
              final results = await _chatService.searchUsers(textEditingValue.text, actorUuid);
              if (!completer.isCompleted) completer.complete(results);
            } catch (e) {
              if (!completer.isCompleted) completer.complete(const Iterable<ChatUser>.empty());
            }
          } else {
            if (!completer.isCompleted) completer.complete(const Iterable<ChatUser>.empty());
          }
        });
        return completer.future;
      },
      displayStringForOption: (ChatUser option) => option.displayName,
      onSelected: (ChatUser selection) {
        setState(() => _selectedAssignee = selection);
        _assigneeController.text = selection.displayName;
        FocusManager.instance.primaryFocus?.unfocus();
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        if (_assigneeController.text.isNotEmpty) {
           textEditingController.text = _assigneeController.text;
        }
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: !_isEditMode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Assignee Nickname',
            labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
            hintText: 'Start typing to search...',
            hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
          ),
          validator: (v) => _selectedAssignee == null ? 'Please select a user' : null,
        );
      },
    );
  }
  
  Widget _buildBasicInfoSection(bool canSendNormal, bool canSendMeds) {
     return Column(
      children: [
        if (canSendNormal && canSendMeds)
          SwitchListTile(
            title: const Text('This is a medication', style: TextStyle(color: Colors.white)),
            value: _currentTask.isMedication,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) => setState(() => _currentTask.isMedication = val),
          ),
         if (_currentTask.isMedication)
          Autocomplete<Medication>(
            initialValue: TextEditingValue(text: _currentTask.nameController.text),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) { return const Iterable<Medication>.empty(); }
              return _medicationService.getSuggestions(textEditingValue.text);
            },
            displayStringForOption: (Medication option) => option.displayName,
            onSelected: (Medication selection) {
              _currentTask.nameController.text = selection.displayName;
              setState(() {
                _currentTask.selectedMedication = selection;
              });
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              if (textEditingController.text != _currentTask.nameController.text) {
                textEditingController.text = _currentTask.nameController.text;
              }
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                    labelText: 'Medication Name',
                    hintText: 'Start typing to search...',
                    labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                    hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round()))),
                validator: (v) => v!.isEmpty ? 'Medication name is required' : null,
              );
            },
          )
        else
          TextFormField(
            controller: _currentTask.nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                labelText: 'Task Name',
                hintText: 'e.g., Drink Water',
                labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round()))),
            validator: (v) => v!.isEmpty ? 'Task name is required' : null,
            onChanged: (v) => setState(() {}),
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _currentTask.descriptionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round()))),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSchedulingSection() {
     return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined, color: Colors.white),
          title: const Text('Start Date', style: TextStyle(color: Colors.white)),
          trailing: Text(DateFormat.yMMMd().format(_currentTask.startDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: _currentTask.startDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null) setState(() => _currentTask.startDate = pickedDate);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ScheduleType>(
          value: _currentTask.scheduleType,
          iconEnabledColor: Colors.white,
          dropdownColor: Theme.of(context).colorScheme.surface,
          selectedItemBuilder: (BuildContext context) {
            return ScheduleType.values.map<Widget>((ScheduleType item) {
              String text = '';
              switch(item) {
                case ScheduleType.once: text = 'Once a Day'; break;
                case ScheduleType.nTimes: text = 'Multiple Times a Day'; break;
                case ScheduleType.interval: text = 'Every Few Hours (Interval)'; break;
                case ScheduleType.mealBased: text = 'With Meals'; break;
                case ScheduleType.bedtime: text = 'At Bedtime'; break;
              }
              return Text(text, style: const TextStyle(color: Colors.white));
            }).toList();
          },
          decoration: InputDecoration(
              labelText: 'Frequency',
              labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round()))),
           items: const [
            DropdownMenuItem(value: ScheduleType.once, child: Text('Once a Day')),
            DropdownMenuItem(value: ScheduleType.nTimes, child: Text('Multiple Times a Day')),
            DropdownMenuItem(value: ScheduleType.interval, child: Text('Every Few Hours (Interval)')),
            DropdownMenuItem(value: ScheduleType.mealBased, child: Text('With Meals')),
            DropdownMenuItem(value: ScheduleType.bedtime, child: Text('At Bedtime')),
          ],
          onChanged: (val) => setState(() => _currentTask.scheduleType = val!),
        ),
        const SizedBox(height: 20),
        _buildDynamicScheduleDetails(),
        const SizedBox(height: 16),
        _buildDurationSection(),
      ],
    );
  }
  
  Widget _buildDynamicScheduleDetails() {
     switch (_currentTask.scheduleType) {
      case ScheduleType.once: return _buildOnceDayForm();
      case ScheduleType.nTimes: return _buildNTimesDayForm();
      case ScheduleType.interval: return _buildIntervalForm();
      case ScheduleType.mealBased: return _buildMealBasedForm();
      case ScheduleType.bedtime: return const ListTile(leading: Icon(Icons.bedtime_outlined, color: Colors.white), title: Text('Task will be scheduled at bedtime.', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildDurationSection() {
     return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Set Duration (Optional)', style: TextStyle(color: Colors.white)),
        leading: const Icon(Icons.calendar_today_outlined, color: Colors.white),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        initiallyExpanded: _currentTask.durationController.text.isNotEmpty,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _currentTask.durationController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: 'For how many days?',
                  hintText: 'e.g., 7 for one week',
                  labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
                  hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
                  border: const OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnceDayForm() {
    return ListTile(
      leading: const Icon(Icons.access_time, color: Colors.white),
      title: const Text('Time', style: TextStyle(color: Colors.white)),
      trailing: Text(_currentTask.onceTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
      onTap: () async {
        final time = await showTimePicker(context: context, initialTime: _currentTask.onceTime);
        if (time != null) setState(() => _currentTask.onceTime = time);
      },
    );
  }

  Widget _buildNTimesDayForm() {
    return Column(
      children: [
        TextFormField(
          initialValue: _currentTask.nTimesCount.toString(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
              labelText: 'How many times a day?',
              labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round()))),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final newCount = int.tryParse(val) ?? 1;
            if (newCount < 1) return;
            setState(() {
              _currentTask.nTimesCount = newCount;
              while (_currentTask.strictTimes.length < newCount) { _currentTask.strictTimes.add(const TimeOfDay(hour: 20, minute: 0)); }
              while (_currentTask.strictTimes.length > newCount) { _currentTask.strictTimes.removeLast(); }
            });
          },
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Theme.of(context).primaryColor,
          ),
          segments: const [
            ButtonSegment(value: true, label: Text('Specific Times'), icon: Icon(Icons.timer_outlined)),
            ButtonSegment(value: false, label: Text('By Interval'), icon: Icon(Icons.hourglass_empty)),
          ],
          selected: {_currentTask.isNTimesStrict},
          onSelectionChanged: (selection) => setState(() => _currentTask.isNTimesStrict = selection.first),
        ),
        const SizedBox(height: 16),
        if (_currentTask.isNTimesStrict)
          ...List.generate(_currentTask.nTimesCount, (index) {
            return ListTile(
              leading: Text('${index + 1}.', style: const TextStyle(color: Colors.white)),
              title: const Text('Time', style: TextStyle(color: Colors.white)),
              trailing: Text(_currentTask.strictTimes[index].format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: _currentTask.strictTimes[index]);
                if (time != null) setState(() => _currentTask.strictTimes[index] = time);
              },
            );
          })
        else
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _currentTask.nTimesInterval.toString(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: 'Hours Apart',
                      labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round()))),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => _currentTask.nTimesInterval = int.tryParse(val) ?? 0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  title: const Text('Starting At', style: TextStyle(color: Colors.white)),
                  subtitle: Text(_currentTask.nTimesStartTime.format(context), style: const TextStyle(color: Colors.white70)),
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: _currentTask.nTimesStartTime);
                    if (time != null) setState(() => _currentTask.nTimesStartTime = time);
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildIntervalForm() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _currentTask.intervalHours.toString(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                labelText: 'Every X Hours',
                labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round()))),
            keyboardType: TextInputType.number,
            onChanged: (val) => _currentTask.intervalHours = int.tryParse(val) ?? 0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ListTile(
            title: const Text('Starting At', style: TextStyle(color: Colors.white)),
            subtitle: Text(_currentTask.intervalStartTime.format(context), style: const TextStyle(color: Colors.white70)),
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: _currentTask.intervalStartTime);
              if (time != null) setState(() => _currentTask.intervalStartTime = time);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMealBasedForm() {
    return Column(
      children: [
        SegmentedButton<MealRelation>(
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withAlpha((0.1 * 255).round()),
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Theme.of(context).primaryColor,
          ),
          segments: const [
            ButtonSegment(value: MealRelation.before, label: Text('Before Meal')),
            ButtonSegment(value: MealRelation.after, label: Text('After Meal')),
          ],
          selected: {_currentTask.mealRelation},
          onSelectionChanged: (selection) => setState(() => _currentTask.mealRelation = selection.first),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8.0,
          children: ['breakfast', 'lunch', 'dinner'].map((meal) {
            final isSelected = _currentTask.selectedMeals.contains(meal);
            return FilterChip(
              label: Text(meal[0].toUpperCase() + meal.substring(1)),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              selected: isSelected,
              backgroundColor: Colors.blueGrey.shade100,
              selectedColor: Theme.of(context).primaryColor,
              onSelected: (selected) {
                setState(() {
                  if (selected) { _currentTask.selectedMeals.add(meal); } else { _currentTask.selectedMeals.remove(meal); }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFormContainer({required Widget child}) {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
              hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).round())),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withAlpha((0.3 * 255).round())),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Theme.of(context).primaryColor,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)));
}