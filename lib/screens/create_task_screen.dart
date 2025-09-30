// lib/screens/create_task_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../models/task_model.dart';
import '../providers/ddi_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../services/medication_service.dart';
import '../widgets/glass_container.dart';

enum ScheduleType { once, nTimes, interval, mealBased, bedtime }
enum MealRelation { before, after }

class CreateTaskScreen extends StatefulWidget {
  final AppTask? taskToEdit;
  const CreateTaskScreen({super.key, this.taskToEdit});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final MedicationService _medicationService = MedicationService();

  bool _isMedication = false;
  Medication? _selectedMedication;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  ScheduleType _scheduleType = ScheduleType.once;
  TimeOfDay _onceTime = const TimeOfDay(hour: 9, minute: 0);
  int _nTimesCount = 2;
  bool _isNTimesStrict = true;
  final List<TimeOfDay> _strictTimes = [
    const TimeOfDay(hour: 9, minute: 0),
    const TimeOfDay(hour: 21, minute: 0),
  ];
  int _nTimesInterval = 6;
  TimeOfDay _nTimesStartTime = const TimeOfDay(hour: 8, minute: 0);
  int _intervalHours = 2;
  TimeOfDay _intervalStartTime = const TimeOfDay(hour: 8, minute: 0);
  MealRelation _mealRelation = MealRelation.before;
  final Set<String> _selectedMeals = {'breakfast', 'dinner'};
  final _durationController = TextEditingController();
  bool _isSubmitting = false;
  bool get _isEditMode => widget.taskToEdit != null;

  TimeOfDay _addHoursToTimeOfDay(TimeOfDay time, int hoursToAdd) {
    final dt = DateTime(0, 1, 1, time.hour, time.minute).add(Duration(hours: hoursToAdd));
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
  TimeOfDay _parseTime(String timeString) {
    try {
      if (timeString.toLowerCase().contains('t')) {
        final dateTime = DateTime.parse(timeString);
        return TimeOfDay.fromDateTime(dateTime);
      } else {
        final parts = timeString.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final task = widget.taskToEdit!;
      _nameController.text = task.name;
      _descriptionController.text = task.description ?? '';
      _isMedication = task.isMedication;
      _startDate = task.startDate ?? task.createdAt;
      if (_isMedication && task.medicationId != null) {
        _selectedMedication = Medication(id: task.medicationId!, nameEn: task.name, nameKr: task.name);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final taskProvider = Provider.of<TaskProvider>(context, listen: false);
          Provider.of<DdiProvider>(context, listen: false)
              .checkForNewMedication(_selectedMedication!, taskProvider.tasks);
        });
      }
      if (task.rule != null) {
        final rule = task.rule!;
        _durationController.text = rule.durationDays?.toString() ?? '';
        switch (rule.ruleType) {
          case 'once':
            _scheduleType = ScheduleType.once;
            if (rule.startTime != null) _onceTime = _addHoursToTimeOfDay(_parseTime(rule.startTime!), 9);
            break;
          case 'n_times':
            _scheduleType = ScheduleType.nTimes;
            _nTimesCount = rule.count ?? 2;
            break;
          case 'interval':
            _scheduleType = ScheduleType.interval;
            if (rule.startTime != null) _intervalStartTime = _addHoursToTimeOfDay(_parseTime(rule.startTime!), 9);
            _intervalHours = rule.intervalHours ?? 2;
            break;
          case 'meal_based':
            _scheduleType = ScheduleType.mealBased;
            if (rule.extras != null) {
              try {
                final extras = jsonDecode(rule.extras!);
                _mealRelation = (extras['relation'] == 'after') ? MealRelation.after : MealRelation.before;
                final meals = extras['meals'] as List?;
                if (meals != null && meals.isNotEmpty) {
                  _selectedMeals.clear();
                  _selectedMeals.addAll(meals.map((e) => e.toString()));
                }
              } catch (e) { /* Parsing error */ }
            }
            break;
          case 'bedtime':
            _scheduleType = ScheduleType.bedtime;
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DdiProvider>(context, listen: false).clearConflicts();
      }
    });
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Task' : 'Create New Task'),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader('Task Details'),
                    _buildFormContainer(child: _buildBasicInfoSection()),
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
                          : Text(_isEditMode ? 'Update Task' : 'Create Task'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Consumer<DdiProvider>(
      builder: (context, ddiProvider, child) {
        return Column(
          children: [
            SwitchListTile(
              title: const Text('This is a medication', style: TextStyle(color: Colors.white)),
              value: _isMedication,
              activeColor: Theme.of(context).primaryColor,
              onChanged: (val) {
                setState(() => _isMedication = val);
                if (!val) ddiProvider.clearConflicts();
              },
            ),
            if (_isMedication)
              Autocomplete<Medication>(
                initialValue: TextEditingValue(text: _isEditMode ? _nameController.text : ''),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<Medication>.empty();
                  return _medicationService.getSuggestions(textEditingValue.text);
                },
                displayStringForOption: (Medication option) => option.displayName,
                onSelected: (Medication selection) {
                  _nameController.text = selection.displayName;
                  _selectedMedication = selection;
                  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                  ddiProvider.checkForNewMedication(selection, taskProvider.tasks);
                },
                fieldViewBuilder: (context, c, fn, ofs) => TextFormField(
                  controller: c,
                  focusNode: fn,
                  decoration: const InputDecoration(labelText: 'Medication Name', hintText: 'Start typing...'),
                  validator: (v) => v!.isEmpty ? 'Medication name is required' : null,
                ),
              ),
            if (ddiProvider.isLoading || ddiProvider.newMedicationConflicts.isNotEmpty)
              _buildDdiWarningBox(ddiProvider.newMedicationConflicts, ddiProvider.isLoading),
            if (!_isMedication)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Task Name', hintText: 'e.g., Drink Water'),
                validator: (v) => v!.isEmpty ? 'Task name is required' : null,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
              maxLines: 2,
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildDdiWarningBox(Map<String, String> conflicts, bool isLoading) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'Potential Interaction Found',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...conflicts.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
              child: Text(
                '• Conflicts with ${entry.key} (Level: ${entry.value})',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSchedulingSection() {
    return Column(
      children: [
        _buildStartDateSection(),
        const SizedBox(height: 16),
        DropdownButtonFormField<ScheduleType>(
          value: _scheduleType,
          iconEnabledColor: Colors.white,
          dropdownColor: Theme.of(context).colorScheme.surface,
          decoration: const InputDecoration(labelText: 'Frequency'),
          items: const [
            DropdownMenuItem(value: ScheduleType.once, child: Text('Once a Day')),
            DropdownMenuItem(value: ScheduleType.nTimes, child: Text('Multiple Times a Day')),
            DropdownMenuItem(value: ScheduleType.interval, child: Text('Every Few Hours (Interval)')),
            DropdownMenuItem(value: ScheduleType.mealBased, child: Text('With Meals')),
            DropdownMenuItem(value: ScheduleType.bedtime, child: Text('At Bedtime')),
          ],
          onChanged: (val) => setState(() => _scheduleType = val!),
        ),
        const SizedBox(height: 20),
        _buildDynamicScheduleDetails(),
        const SizedBox(height: 16),
        _buildDurationSection(),
      ],
    );
  }

  Widget _buildStartDateSection() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flag_outlined, color: Colors.white),
      title: const Text('Start Date', style: TextStyle(color: Colors.white)),
      trailing: Text(
        DateFormat.yMMMd().format(_startDate),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: _isEditMode ? DateTime(2020) : DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (pickedDate != null) setState(() => _startDate = pickedDate);
      },
    );
  }

  Widget _buildDynamicScheduleDetails() {
    switch (_scheduleType) {
      case ScheduleType.once: return _buildOnceDayForm();
      case ScheduleType.nTimes: return _buildNTimesDayForm();
      case ScheduleType.interval: return _buildIntervalForm();
      case ScheduleType.mealBased: return _buildMealBasedForm();
      case ScheduleType.bedtime:
        return const ListTile(
          leading: Icon(Icons.bedtime_outlined, color: Colors.white),
          title: Text('Task will be scheduled at bedtime.', style: TextStyle(color: Colors.white)),
        );
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
        initiallyExpanded: _isEditMode && _durationController.text.isNotEmpty,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'For how many days?', hintText: 'e.g., 7', border: OutlineInputBorder()),
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
      trailing: Text(_onceTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
      onTap: () async {
        final time = await showTimePicker(context: context, initialTime: _onceTime);
        if (time != null) setState(() => _onceTime = time);
      },
    );
  }

  Widget _buildNTimesDayForm() {
    return Column(
      children: [
        TextFormField(
          initialValue: _nTimesCount.toString(),
          decoration: const InputDecoration(labelText: 'How many times a day?'),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final newCount = int.tryParse(val) ?? 1;
            if (newCount < 1) return;
            setState(() {
              _nTimesCount = newCount;
              while (_strictTimes.length < newCount) _strictTimes.add(const TimeOfDay(hour: 20, minute: 0));
              while (_strictTimes.length > newCount) _strictTimes.removeLast();
            });
          },
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
           style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withAlpha(25),
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Theme.of(context).primaryColor,
          ),
          segments: const [
            ButtonSegment(value: true, label: Text('Specific Times'), icon: Icon(Icons.timer_outlined)),
            ButtonSegment(value: false, label: Text('By Interval'), icon: Icon(Icons.hourglass_empty)),
          ],
          selected: {_isNTimesStrict},
          onSelectionChanged: (selection) => setState(() => _isNTimesStrict = selection.first),
        ),
        const SizedBox(height: 16),
        if (_isNTimesStrict)
          ...List.generate(_nTimesCount, (index) {
            return ListTile(
              leading: Text('${index + 1}.', style: const TextStyle(color: Colors.white)),
              title: const Text('Time', style: TextStyle(color: Colors.white)),
              trailing: Text(_strictTimes[index].format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: _strictTimes[index]);
                if (time != null) setState(() => _strictTimes[index] = time);
              },
            );
          })
        else
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _nTimesInterval.toString(),
                  decoration: const InputDecoration(labelText: 'Hours Apart'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => _nTimesInterval = int.tryParse(val) ?? 0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  title: const Text('Starting At', style: TextStyle(color: Colors.white)),
                  subtitle: Text(_nTimesStartTime.format(context), style: const TextStyle(color: Colors.white70)),
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: _nTimesStartTime);
                    if (time != null) setState(() => _nTimesStartTime = time);
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
            initialValue: _intervalHours.toString(),
            decoration: const InputDecoration(labelText: 'Every X Hours'),
            keyboardType: TextInputType.number,
            onChanged: (val) => _intervalHours = int.tryParse(val) ?? 0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ListTile(
            title: const Text('Starting At', style: TextStyle(color: Colors.white)),
            subtitle: Text(_intervalStartTime.format(context), style: const TextStyle(color: Colors.white70)),
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: _intervalStartTime);
              if (time != null) setState(() => _intervalStartTime = time);
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
            backgroundColor: Colors.white.withAlpha(25),
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: Theme.of(context).primaryColor,
          ),
          segments: const [
            ButtonSegment(value: MealRelation.before, label: Text('Before Meal')),
            ButtonSegment(value: MealRelation.after, label: Text('After Meal')),
          ],
          selected: {_mealRelation},
          onSelectionChanged: (selection) => setState(() => _mealRelation = selection.first),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8.0,
          children: ['breakfast', 'lunch', 'dinner'].map((meal) {
            return FilterChip(
              label: Text(meal[0].toUpperCase() + meal.substring(1)),
              labelStyle: const TextStyle(color: Colors.black),
              selected: _selectedMeals.contains(meal),
              backgroundColor: Colors.white.withAlpha(50),
              selectedColor: Theme.of(context).primaryColor,
              onSelected: (selected) {
                setState(() {
                  if (selected) _selectedMeals.add(meal);
                  else _selectedMeals.remove(meal);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildFormContainer({required Widget child}) {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            brightness: Brightness.dark,
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.white.withAlpha(180)),
              hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(80))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor)),
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

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isMedication && _selectedMedication == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid medication from the list.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final actorUuid = userProvider.userUuid;

    if (actorUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in.')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    Map<String, dynamic> taskData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'assignee_uuid': actorUuid,
      'sender_uuid': actorUuid,
      'start_date': _formatDate(_startDate),
      'rules': [],
    };

    if (_isMedication) {
      taskData['medication_id'] = _selectedMedication!.id;
    }

    Map<String, dynamic> rule = {};
    switch (_scheduleType) {
      case ScheduleType.once:
        rule['rule_type'] = 'once';
        rule['start_time'] = _formatTimeOfDay(_onceTime);
        break;
      case ScheduleType.nTimes:
        rule['rule_type'] = 'n_times';
        rule['count'] = _nTimesCount;
        if (_isNTimesStrict) {
          rule['extras'] = jsonEncode({
            'strict_times': _strictTimes
                .map((t) => _formatTimeOfDay(t))
                .toList(),
          });
        } else {
          rule['interval_hours'] = _nTimesInterval;
          rule['start_time'] = _formatTimeOfDay(_nTimesStartTime);
        }
        break;
      case ScheduleType.interval:
        rule['rule_type'] = 'interval';
        rule['interval_hours'] = _intervalHours;
        rule['start_time'] = _formatTimeOfDay(_intervalStartTime);
        break;
      case ScheduleType.mealBased:
        rule['rule_type'] = 'meal_based';
        rule['extras'] = jsonEncode({
          'relation': _mealRelation.toString().split('.').last,
          'meals': _selectedMeals.toList(),
        });
        break;
      case ScheduleType.bedtime:
        rule['rule_type'] = 'bedtime';
        break;
    }

    if (_durationController.text.isNotEmpty) {
      rule['duration_days'] = int.tryParse(_durationController.text);
    }

    (taskData['rules'] as List).add(rule);

    bool success = false;
    if (_isEditMode) {
      success = await taskProvider.updateTask(
        taskToUpdate: widget.taskToEdit!,
        newData: taskData,
        actorUuid: actorUuid,
      );
    } else {
      success = await taskProvider.createTask(
        taskData: taskData,
        isMedication: _isMedication,
        actorUuid: actorUuid,
        userUuidForRefresh: actorUuid,
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              taskProvider.errorMessage ?? 'An unknown error occurred.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}