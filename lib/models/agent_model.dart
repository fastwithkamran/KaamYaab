/// Model representing a single reasoning step from the KaamYaab AI orchestrator.
class AgentStep {
  final String agentName;
  final String task;
  final String reasoning;
  final String? decision;
  final String? toolCall;
  final String? output;
  final AgentStepStatus status;
  final DateTime timestamp;
  final bool isMocked;

  const AgentStep({
    required this.agentName,
    required this.task,
    required this.reasoning,
    this.decision,
    this.toolCall,
    this.output,
    required this.status,
    required this.timestamp,
    this.isMocked = false,
  });

  AgentStep copyWith({AgentStepStatus? status, String? output, String? decision, bool? isMocked}) {
    return AgentStep(
      agentName: agentName,
      task: task,
      reasoning: reasoning,
      decision: decision ?? this.decision,
      toolCall: toolCall,
      output: output ?? this.output,
      status: status ?? this.status,
      timestamp: timestamp,
      isMocked: isMocked ?? this.isMocked,
    );
  }
}

enum AgentStepStatus { thinking, done, failed, skipped }

/// The full orchestration trace for a single user request.
class AgentTrace {
  final String requestId;
  final List<AgentStep> steps;
  final String overallStatus; // running | completed | failed
  final DateTime startedAt;
  final DateTime? completedAt;

  const AgentTrace({
    required this.requestId,
    required this.steps,
    required this.overallStatus,
    required this.startedAt,
    this.completedAt,
  });

  AgentTrace copyWith({
    List<AgentStep>? steps,
    String? overallStatus,
    DateTime? completedAt,
  }) {
    return AgentTrace(
      requestId: requestId,
      steps: steps ?? this.steps,
      overallStatus: overallStatus ?? this.overallStatus,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Predefined step labels shown in the Search Progress panel.
class AgentIdentity {
  static const String intent     = 'Understanding your request';
  static const String matching   = 'Finding workers near you';
  static const String surge      = 'Checking demand in your area';
  static const String pricing    = 'Calculating the best price';
  static const String scheduling = 'Checking worker availability';
  static const String booking    = 'Confirming your booking';
  static const String dispute    = 'Reviewing your complaint';
  static const String feedback   = 'Saving your feedback';

  static String emoji(String name) {
    switch (name) {
      case intent:     return '🔍';
      case matching:   return '🎯';
      case surge:      return '📊';
      case pricing:    return '💰';
      case scheduling: return '📅';
      case booking:    return '✅';
      case dispute:    return '⚖️';
      case feedback:   return '⭐';
      default:         return '⚙️';
    }
  }
}
