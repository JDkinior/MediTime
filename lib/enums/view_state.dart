// lib/enums/view_state.dart

/// Representa los diferentes estados en los que se puede encontrar una vista
/// que carga datos.
enum ViewState {
  /// La vista está cargando datos.
  loading,

  /// La vista ha cargado los datos correctamente.
  success,

  /// Ocurrió un error al cargar los datos.
  error,

  /// La carga fue exitosa, pero no hay datos para mostrar.
  empty,
}