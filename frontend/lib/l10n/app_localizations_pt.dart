// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'Início';

  @override
  String get listen => 'Ouvir';

  @override
  String get write => 'Escrever';

  @override
  String get settings => 'Configurações';

  @override
  String get createNote => 'Criar Litten';

  @override
  String get newNote => 'Novo Litten';

  @override
  String get title => 'Título';

  @override
  String get description => 'Descrição';

  @override
  String get optional => '(Opcional)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Criar';

  @override
  String get delete => 'Excluir';

  @override
  String get search => 'Pesquisar';

  @override
  String get searchNotes => 'Pesquisar notas...';

  @override
  String get noNotesTitle => 'Crie seu primeiro Litten';

  @override
  String get noNotesSubtitle =>
      'Gerencie voz, texto e escrita à mão\nem um espaço integrado';

  @override
  String get noSearchResults => 'Sem resultados de pesquisa';

  @override
  String noSearchResultsSubtitle(String query) {
    return 'Nenhuma nota encontrada correspondente a \"$query\"';
  }

  @override
  String get clearSearch => 'Limpar pesquisa';

  @override
  String get deleteNote => 'Excluir Nota';

  @override
  String get deleteNoteConfirm =>
      'Tem certeza de que deseja excluir esta nota?\nTodos os arquivos serão excluídos juntos.';

  @override
  String get noteDeleted => 'Nota excluída';

  @override
  String noteCreated(String title) {
    return '\'$title\' criado';
  }

  @override
  String noteSelected(String title) {
    return '$title selecionado';
  }

  @override
  String freeLimitReached(int limit) {
    return 'A versão gratuita permite apenas $limit notas.';
  }

  @override
  String get upgradeToStandard => 'Atualizar para Padrão';

  @override
  String get upgradeFeatures =>
      'Atualize para Padrão e obtenha:\n\n• Criação ilimitada de notas\n• Armazenamento ilimitado de arquivos\n• Remoção de anúncios\n• Sincronização na nuvem';

  @override
  String get later => 'Mais tarde';

  @override
  String get upgrade => 'Atualizar';

  @override
  String get adBannerText =>
      'Área de anúncios - Remover com atualização Padrão';

  @override
  String get enterTitle => 'Por favor, insira um título';

  @override
  String createNoteFailed(String error) {
    return 'Falha ao criar nota: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'Falha ao excluir nota: $error';
  }

  @override
  String get upgradeComingSoon =>
      'O recurso de atualização estará disponível em breve';
}
