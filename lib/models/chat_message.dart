// lib/models/chat_message.dart

/// Modelo de datos inmutable que representa un mensaje intercambiado
/// en la conversación del asistente virtual (Midi).
class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.prescriptionData,
    this.showAdherenceChart = false,
    this.adherenceChartData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isUser;
  final bool isStreaming;
  final Map<String, dynamic>? prescriptionData;
  final bool showAdherenceChart;
  final Map<String, dynamic>? adherenceChartData;
  final DateTime timestamp;

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isStreaming,
    Map<String, dynamic>? prescriptionData,
    bool? showAdherenceChart,
    Map<String, dynamic>? adherenceChartData,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isStreaming: isStreaming ?? this.isStreaming,
      prescriptionData: prescriptionData ?? this.prescriptionData,
      showAdherenceChart: showAdherenceChart ?? this.showAdherenceChart,
      adherenceChartData: adherenceChartData ?? this.adherenceChartData,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
