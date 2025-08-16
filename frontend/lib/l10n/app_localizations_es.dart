// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Inicio';

  @override
  String get listen => 'Escuchar';

  @override
  String get write => 'Escribir';

  @override
  String get settings => 'Configuración';

  @override
  String get createNote => 'Crear Litten';

  @override
  String get newNote => 'Nuevo Litten';

  @override
  String get title => 'Título';

  @override
  String get description => 'Descripción';

  @override
  String get optional => '(Opcional)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Crear';

  @override
  String get delete => 'Eliminar';

  @override
  String get search => 'Buscar';

  @override
  String get searchNotes => 'Buscar notas...';

  @override
  String get noNotesTitle => 'Crea tu primer Litten';

  @override
  String get noNotesSubtitle =>
      'Gestiona voz, texto y escritura a mano\nen un espacio integrado';

  @override
  String get noSearchResults => 'Sin resultados de búsqueda';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'No se encontraron notas que coincidan con \"$query\"';
  }

  @override
  String get clearSearch => 'Limpiar búsqueda';

  @override
  String get deleteNote => 'Eliminar Nota';

  @override
  String get deleteNoteConfirm =>
      '¿Estás seguro de que quieres eliminar esta nota?\nTodos los archivos se eliminarán juntos.';

  @override
  String get noteDeleted => 'Nota eliminada';

  @override
  String noteCreated(String title) {
    return '\'$title\' creado';
  }

  @override
  String noteSelected(String title) {
    return '$title seleccionado';
  }

  @override
  String freeLimitReached(int limit) {
    return 'La versión gratuita permite solo $limit notas.';
  }

  @override
  String get upgradeToStandard => 'Actualizar a Estándar';

  @override
  String get upgradeFeatures =>
      'Actualiza a Estándar y obtén:\n\n• Creación ilimitada de notas\n• Almacenamiento ilimitado de archivos\n• Eliminación de anuncios\n• Sincronización en la nube';

  @override
  String get later => 'Más tarde';

  @override
  String get upgrade => 'Actualizar';

  @override
  String get adBannerText =>
      'Área de anuncios - Eliminar con actualización Estándar';

  @override
  String get enterTitle => 'Por favor ingresa un título';

  @override
  String createNoteFailed(String error) {
    return 'Error al crear nota: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Error al eliminar nota: $error';
  }

  @override
  String get upgradeComingSoon =>
      'La función de actualización estará disponible pronto';
}
