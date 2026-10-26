import os
import sys
import win32com.client
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

# Institutional Color Palette (Universidad de Cundinamarca)
COLOR_UDEC_GREEN_DARK = RGBColor(0, 85, 40)      # Primary deep green #005528
COLOR_UDEC_GREEN = RGBColor(0, 114, 54)          # UdeC classic green #007236
COLOR_UDEC_GREEN_LIGHT = RGBColor(235, 246, 238) # Light green card background #EBF6EE
COLOR_UDEC_GOLD = RGBColor(184, 134, 11)         # Dark goldenrod accent
COLOR_TEXT_PRIMARY = RGBColor(30, 41, 59)        # Slate 800 dark text
COLOR_TEXT_MUTED = RGBColor(100, 116, 139)       # Slate 500 subtitle
COLOR_TEXT_WHITE = RGBColor(255, 255, 255)
COLOR_CARD_BG = RGBColor(255, 255, 255)          # Crisp white card
COLOR_CARD_BORDER = RGBColor(218, 225, 231)      # Slate 300 border
COLOR_ACCENT_BG = RGBColor(240, 253, 244)        # Mint light card
COLOR_ACCENT_BORDER = RGBColor(134, 239, 172)    # Mint border
COLOR_HIGHLIGHT_RED = RGBColor(185, 28, 28)      # For problem/risks callout
COLOR_HEADER_BG = RGBColor(0, 102, 51)          # Table / card header green
COLOR_ROW_ALT = RGBColor(245, 248, 245)          # Table alternating row

BASE_TEMPLATE = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\clean_template_17.pptx'
OUT_PPTX = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\C3_Desarrollo de una aplicacion movil para la gestion de tratamientos medicos_Delgado&Arevalo.pptx'
OUT_PDF = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\C3_Desarrollo de una aplicacion movil para la gestion de tratamientos medicos_Delgado&Arevalo.pdf'

prs = Presentation(BASE_TEMPLATE)

def setup_header(slide, category, title):
    cat_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.42), Inches(4.5), Inches(0.35))
    ctf = cat_box.text_frame
    ctf.word_wrap = True
    ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
    cp = ctf.paragraphs[0]
    cp.text = category.upper()
    cp.font.size = Pt(10)
    cp.font.bold = True
    cp.font.color.rgb = COLOR_UDEC_GREEN
    
    title_box = slide.shapes.add_textbox(Inches(0.8), Inches(1.18), Inches(11.7), Inches(0.55))
    ttf = title_box.text_frame
    ttf.word_wrap = True
    ttf.margin_left = ttf.margin_top = ttf.margin_right = ttf.margin_bottom = 0
    tp = ttf.paragraphs[0]
    tp.text = title
    tp.font.size = Pt(20)
    tp.font.bold = True
    tp.font.color.rgb = COLOR_UDEC_GREEN_DARK

def add_card(slide, left, top, width, height, bg_color=COLOR_CARD_BG, border_color=COLOR_CARD_BORDER):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = bg_color
    shape.line.color.rgb = border_color
    shape.line.width = Pt(1.2)
    return shape

def add_card_header(slide, left, top, width, height, text, bg_color=COLOR_HEADER_BG, text_color=COLOR_TEXT_WHITE):
    header = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    header.fill.solid()
    header.fill.fore_color.rgb = bg_color
    header.line.fill.background()
    tf = header.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = text_color
    p.alignment = PP_ALIGN.CENTER
    return header

def add_kpi_badge(slide, left, top, width, height, num_text, label_text, sub_text=None, is_highlight=False):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = COLOR_UDEC_GREEN_LIGHT if not is_highlight else RGBColor(254, 242, 242)
    shape.line.color.rgb = COLOR_UDEC_GREEN if not is_highlight else COLOR_HIGHLIGHT_RED
    shape.line.width = Pt(1.5)
    
    tf = shape.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_top = tf.margin_bottom = Inches(0.04)
    tf.margin_left = tf.margin_right = Inches(0.08)
    
    p1 = tf.paragraphs[0]
    p1.text = num_text
    p1.font.size = Pt(22)
    p1.font.bold = True
    p1.font.color.rgb = COLOR_UDEC_GREEN_DARK if not is_highlight else COLOR_HIGHLIGHT_RED
    p1.alignment = PP_ALIGN.CENTER
    
    p2 = tf.add_paragraph()
    p2.text = label_text
    p2.font.size = Pt(10)
    p2.font.bold = True
    p2.font.color.rgb = COLOR_TEXT_PRIMARY
    p2.alignment = PP_ALIGN.CENTER
    
    if sub_text:
        p3 = tf.add_paragraph()
        p3.text = sub_text
        p3.font.size = Pt(8.5)
        p3.font.color.rgb = COLOR_TEXT_MUTED
        p3.alignment = PP_ALIGN.CENTER

def add_bullets_box(slide, left, top, width, height, items, font_size=11):
    tbox = slide.shapes.add_textbox(left, top, width, height)
    tf = tbox.text_frame
    tf.word_wrap = True
    tf.margin_left = Inches(0.12)
    tf.margin_right = Inches(0.12)
    tf.margin_top = Inches(0.1)
    tf.margin_bottom = Inches(0.1)
    
    for idx, (title, desc) in enumerate(items):
        p = tf.paragraphs[0] if idx == 0 else tf.add_paragraph()
        p.space_after = Pt(4)
        run_title = p.add_run()
        run_title.text = "• " + title + (": " if desc else "")
        run_title.font.bold = True
        run_title.font.size = Pt(font_size)
        run_title.font.color.rgb = COLOR_UDEC_GREEN_DARK
        
        if desc:
            run_desc = p.add_run()
            run_desc.text = desc
            run_desc.font.size = Pt(font_size)
            run_desc.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 1: PORTADA INSTITUCIONAL
# =============================================================
s1 = prs.slides[0]
for shape in list(s1.shapes):
    if shape.name in ['CuadroTexto 8', 'CuadroTexto 10']:
        sp = shape._element
        sp.getparent().remove(sp)

title_box = s1.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(2.3))
tf = title_box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

p_cat = tf.paragraphs[0]
p_cat.text = "PROYECTO DE GESTIÓN DEL CONOCIMIENTO (PGC) • CICLO III"
p_cat.font.size = Pt(11)
p_cat.font.bold = True
p_cat.font.color.rgb = COLOR_UDEC_GREEN
p_cat.space_after = Pt(4)

p_title = tf.add_paragraph()
p_title.text = "DESARROLLO DE UNA APLICACIÓN MÓVIL PARA LA GESTIÓN DE TRATAMIENTOS MÉDICOS (MEDITIME)"
p_title.font.size = Pt(18)
p_title.font.bold = True
p_title.font.color.rgb = COLOR_UDEC_GREEN_DARK
p_title.space_after = Pt(6)

p_sub = tf.add_paragraph()
p_sub.text = "Sustentación de Segunda Entrega • Semestre IX: Cierre, Evaluación de Impacto y Transferencia"
p_sub.font.size = Pt(11.5)
p_sub.font.bold = True
p_sub.font.color.rgb = COLOR_TEXT_MUTED

meta_box = s1.shapes.add_textbox(Inches(0.8), Inches(4.35), Inches(5.5), Inches(2.2))
mtf = meta_box.text_frame
mtf.word_wrap = True
mtf.margin_left = mtf.margin_top = mtf.margin_right = mtf.margin_bottom = 0

p1 = mtf.paragraphs[0]
p1.text = "Creadores de Oportunidades (Autores):"
p1.font.size = Pt(10.5)
p1.font.bold = True
p1.font.color.rgb = COLOR_UDEC_GREEN_DARK

p2 = mtf.add_paragraph()
p2.text = "• Jorge Eliecer Delgado Cortés | C.C. 1.070.016.489 (Estudiante Noveno Semestre)\n• Johan Alexander Arévalo Contreras | C.C. 1.070.017.382"
p2.font.size = Pt(10.5)
p2.font.color.rgb = COLOR_TEXT_PRIMARY
p2.space_after = Pt(6)

p3 = mtf.add_paragraph()
p3.text = "Acompañamiento Académico e Institucional:"
p3.font.size = Pt(10.5)
p3.font.bold = True
p3.font.color.rgb = COLOR_UDEC_GREEN_DARK

p4 = mtf.add_paragraph()
p4.text = "• Docente Líder de Ciclo III: Ing. Néstor Javier García Guzmán\n• Gestora del Conocimiento: Ing. Nohora Angélica Millán A.\n• Programa de Ingeniería de Sistemas y Computación • Seccional Ubaté (2026-2)"
p4.font.size = Pt(10)
p4.font.color.rgb = COLOR_TEXT_MUTED

# =============================================================
# SLIDE 2: PROBLEMÁTICA TERRITORIAL Y EVIDENCIA EMPÍRICA (Criterio 1 - 15%)
# =============================================================
s2 = prs.slides[1]
setup_header(s2, "1. Problemática Territorial y Evidencia", "Incumplimiento Terapéutico y Brecha de Salud en el Valle de Ubaté")

add_card(s2, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s2, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "EVIDENCIA EPIDEMIOLÓGICA Y CAUSAS RAÍZ")
add_kpi_badge(s2, Inches(1.0), Inches(2.38), Inches(2.4), Inches(1.15), "59%", "No Adherencia", "Pacientes crónicos en Colombia (OMS, 2023)", is_highlight=True)
add_kpi_badge(s2, Inches(3.6), Inches(2.38), Inches(2.6), Inches(1.15), "68%", "Olvido Involuntario", "Causa principal del abandono terapéutico", is_highlight=True)

s2_bullets_left = [
    ("Polifarmacia Crónica", "Adultos mayores consumen simultáneamente entre 3 y 6 fármacos diarios con esquemas y horarios dispares."),
    ("Pérdida de Prescripciones", "Deterioro o extravío de fórmulas médicas impresas y falta de trazabilidad clínica."),
    ("Consecuencias Críticas", "Agravamiento de patologías prevenibles, complicaciones cardiovasculares y hospitalizaciones de alto costo.")
]
add_bullets_box(s2, Inches(0.9), Inches(3.65), Inches(5.4), Inches(2.65), s2_bullets_left, font_size=10.5)

add_card(s2, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s2, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "CONTEXTO EN UBATÉ Y DEVOLUCIÓN AL TERRITORIO")

s2_bullets_right = [
    ("Población Diana en la Provincia", "Adultos mayores y enfermos crónicos (hipertensión, diabetes, artritis) en zonas urbanas y rurales del Valle de Ubaté."),
    ("Barreras Territoriales", "Dificultad de movilidad hacia centros asistenciales de mayor complejidad y alta dependencia de cuidadores familiares."),
    ("Baja Alfabetización Digital", "Rechazo hacia interfaces médicas complejas que carecen de accesibilidad y soporte asistivo para la tercera edad."),
    ("Qué Cambió con MediTime", "Transformación del autocuidado: adopción comunitaria activa, recordatorios de hardware que no fallan, digitalización rápida de recetas y reportes clínicos en PDF para dialogar con el médico tratante.")
]
add_bullets_box(s2, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s2_bullets_right, font_size=10.5)

# =============================================================
# SLIDE 3: JUSTIFICACIÓN Y ARTICULACIÓN INSTITUCIONAL MEDIT
# =============================================================
s3 = prs.slides[2]
setup_header(s3, "2. Justificación y Marco Estratégico", "Articulación con el Modelo Educativo MEDIT y los ODS")

add_card(s3, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s3, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "MODELO EDUCATIVO DIGITAL TRANSMODERNO (MEDIT)")

s3_medit = [
    ("Sujeto Libre, Autónomo y Responsable", "MediTime materializa el ideal formativo de la Universidad de Cundinamarca, empoderando al paciente para que asuma soberanía informada sobre su propio tratamiento médico."),
    ("Ética Formativa en la IA (Midi AI)", "El asistente conversacional encarna la filosofía institucional: actúa mediante el diálogo constructivo, el respeto a la privacidad de datos y el acompañamiento empático."),
    ("Translocalidad y Compromiso Social", "La ingeniería trasciende el aula: el software resuelve un dolor real de la provincia de Ubaté, articulando el conocimiento científico con las necesidades del territorio.")
]
add_bullets_box(s3, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s3_medit, font_size=10.8)

add_card(s3, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s3, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "ALINEACIÓN CON LA AGENDA 2030 (ODS)")

s3_ods = [
    ("ODS 3: Salud y Bienestar (Metas 3.4 y 3.8)", "Mitigación de la mortalidad prematura por enfermedades no transmisibles. Optimización sistemática de la adherencia farmacológica y prevención de complicaciones graves."),
    ("ODS 9: Industria, Innovación e Infraestructura", "Implementación de arquitectura móvil moderna (Clean Architecture, Flutter, IA multimodal en el borde) sin barreras económicas ni comerciales para la comunidad regional."),
    ("ODS 10: Reducción de las Desigualdades (Meta 10.2)", "Herramientas de inclusión real: Modo Simplificado para la tercera edad, síntesis y reconocimiento por voz (TTS/Whisper) y soporte integral para cuidadores y veterinaria.")
]
add_bullets_box(s3, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s3_ods, font_size=10.8)

# =============================================================
# SLIDE 4: PROPÓSITO DEL PROYECTO Y OBJETIVOS (C3 - IX)
# =============================================================
s4 = prs.slides[3]
setup_header(s4, "3. Propósito y Alcance del Semestre", "Objetivos Formulados para el Cierre, Evaluación y Transferencia")

add_card(s4, Inches(0.8), Inches(1.85), Inches(11.7), Inches(1.4), bg_color=COLOR_ACCENT_BG, border_color=COLOR_ACCENT_BORDER)
add_card_header(s4, Inches(0.8), Inches(1.85), Inches(11.7), Inches(0.38), "OBJETIVO GENERAL DEL PROYECTO")

g_box = s4.shapes.add_textbox(Inches(0.95), Inches(2.28), Inches(11.4), Inches(0.9))
gtf = g_box.text_frame
gtf.word_wrap = True
gtf.margin_left = gtf.margin_top = gtf.margin_right = gtf.margin_bottom = 0
gp = gtf.paragraphs[0]
gp.text = "Desarrollar y transferir MediTime (v2.36.0), una plataforma móvil multiplataforma para la gestión integral de tratamientos médicos en la población del Valle de Ubaté, que garantice el acceso digital a prescripciones, el monitoreo posológico, recordatorios automáticos de alta fidelidad, asistencia bilingüe por IA y la generación de reportes clínicos certificados para la devolución efectiva al territorio."
gp.font.size = Pt(11.2)
gp.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s4, Inches(0.8), Inches(3.4), Inches(11.7), Inches(3.0))
add_card_header(s4, Inches(0.8), Inches(3.4), Inches(11.7), Inches(0.38), "OBJETIVOS ESPECÍFICOS VERIFICABLES (CICLO III - SEMESTRE IX)")

s4_objs = [
    ("OE1: Arquitectura y Resiliencia Nativa", "Consolidar Clean Architecture con persistencia offline-first SQLite, sincronización bidireccional Cloud Firestore y alarmas de hardware Android que rompen el Doze Mode."),
    ("OE2: Inteligencia y Accesibilidad Inclusiva", "Integrar visión artificial para extracción OCR de recetas médicas físicas con Groq LPU y asistente conversacional de voz natural (Midi AI) con comandos interactivos Tool Calling."),
    ("OE3: Ecosistema Multiperfil Territorial", "Implementar y desplegar los módulos Modo Cuidador (supervisión de dependientes con código de colores) y Modo Animales (calendario y dosificación veterinaria independiente)."),
    ("OE4: Calidad y Transferencia Comunitaria", "Evaluar la calidad del sistema bajo la norma ISO/IEC 25010 (4 características), ejecutar talleres de devolución social en Ubaté y formalizar el producto académico y dossier C3.")
]
add_bullets_box(s4, Inches(0.95), Inches(3.85), Inches(11.4), Inches(2.45), s4_objs, font_size=10.5)

# =============================================================
# SLIDE 5: ATENCIÓN Y CIERRE DE OBSERVACIONES (Criterio 5 - 10%)
# =============================================================
s5 = prs.slides[4]
setup_header(s5, "4. Mejora Continua y Evolución", "Atención Rigurosa a las Observaciones de la Primera Entrega")

obs_table_shape = s5.shapes.add_table(6, 3, Inches(0.8), Inches(1.85), Inches(11.7), Inches(4.55))
table = obs_table_shape.table
table.columns[0].width = Inches(3.3)
table.columns[1].width = Inches(4.5)
table.columns[2].width = Inches(3.9)

headers = ["Observación Señalada por Jurado", "Ajuste e Implementación Realizada", "Efecto Comprobado y Evidencia"]
for col_idx, text in enumerate(headers):
    cell = table.cell(0, col_idx)
    cell.fill.solid()
    cell.fill.fore_color.rgb = COLOR_HEADER_BG
    p = cell.text_frame.paragraphs[0]
    p.text = text
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = COLOR_TEXT_WHITE
    p.alignment = PP_ALIGN.CENTER

rows_data = [
    ("1. Impacto Territorial:\nAusencia de evidencias formales de devolución comunitaria en la región.",
     "Diseño y ejecución de protocolo de devolución: 3 talleres comunitarios en Ubaté y entrega de cartillas impresas para la tercera edad.",
     "Validación directa con pacientes y cuidadores; adopción real en el territorio evidenciada."),
    ("2. Evaluación de Calidad:\nFalta de métricas estandarizadas de calidad de software.",
     "Implementación formal de ISO/IEC 25010 (4 características: Funcional, Fiabilidad, Usabilidad SUS, Rendimiento) + 194 tests.",
     "Aprobación del 100% en test suite (flutter test) y puntaje de usabilidad SUS de 88.5/100."),
    ("3. Documentación C3:\nRequerimiento de manuales técnicos institucionalizados.",
     "Elaboración del dossier C3 completo: Manual de Usuario (40p), Manual Técnico (44p) y Plan de Sostenibilidad con matriz RACI (23p).",
     "Documentación técnica oficial compilada y aprobada para repositorio institucional."),
    ("4. Divulgación Científica:\nFalta de delimitación del producto académico final.",
     "Consolidación de manuscrito IMRyD y postulación a Revista UIS Ingenierías (Publindex Cat B / Scopus).",
     "Modalidad de producto académico formalmente estructurada y articulada con la investigación."),
    ("5. Control y Trazabilidad:\nEvidenciar cierre de fases y etiquetado final de versión.",
     "Auditoría con 100% de actividades anteriores cerradas con commits; avance al 78.6% en 2026-2; etiquetado Git v2.36.0.",
     "Trazabilidad íntegra de ingeniería desde el repositorio central de GitHub.")
]

for row_idx, row in enumerate(rows_data, start=1):
    for col_idx, text in enumerate(row):
        cell = table.cell(row_idx, col_idx)
        cell.fill.solid()
        cell.fill.fore_color.rgb = COLOR_ROW_ALT if row_idx % 2 == 1 else RGBColor(255, 255, 255)
        p = cell.text_frame.paragraphs[0]
        p.text = text
        p.font.size = Pt(9.5)
        p.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 6: GESTIÓN ÁGIL DEL PROYECTO Y TRAZABILIDAD (Criterio 6 - 5%)
# =============================================================
s6 = prs.slides[5]
setup_header(s6, "5. Gestión Ágil y Cronograma", "Metodología de Desarrollo, Auditoría de Fases y Control de Versiones")

add_card(s6, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s6, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "MARCO ÁGIL: KANBAN & ITERACIONES DE 3 SEMANAS")

s6_agile = [
    ("Iteraciones Estructuradas", "Ciclos de desarrollo de 3 semanas priorizados por la relación Valor de Impacto vs. Esfuerzo de Ingeniería."),
    ("Definition of Ready (DoR)", "Historias de usuario con criterios de aceptación técnicos, diagramas de flujo y modelos de datos aprobados antes de iniciar desarrollo."),
    ("Definition of Done (DoD)", "Código con Sound Null Safety, 0 advertencias en flutter analyze, pruebas unitarias aprobadas y revisión de Pull Request en GitHub."),
    ("Trazabilidad Anterior (2025-1)", "Auditoría del 100% de cumplimiento sobre las 8 actividades originales, todas cerradas y verificadas mediante commits Git (ca8e51b, af224ac, a2aaa1f).")
]
add_bullets_box(s6, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s6_agile, font_size=10.2)

add_card(s6, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s6, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "ESTADO DEL CRONOGRAMA 2026-2 & VERSIÓN FINAL")

add_kpi_badge(s6, Inches(7.0), Inches(2.38), Inches(1.7), Inches(1.15), "78.6%", "Avance General", "11/14 actividades", is_highlight=False)
add_kpi_badge(s6, Inches(8.8), Inches(2.38), Inches(1.7), Inches(1.15), "9", "Finalizadas", "64.3% del plan", is_highlight=False)
add_kpi_badge(s6, Inches(10.6), Inches(2.38), Inches(1.7), Inches(1.15), "v2.36.0", "Tag Git Release", "Commit 6cbf86e", is_highlight=False)

s6_bullets_right = [
    ("Actividades Finalizadas (9/14)", "Optimización algorítmica de dosis, widgets Android, OCR con visión, temas oscuros/accesibles, Modo Cuidador, Modo Animales, suite de tests y compilación C3."),
    ("Actividades en Curso (2/14)", "Pruebas de compatibilidad en dispositivos físicos heterogéneos y preparación de versión Release APK."),
    ("Actividades de Cierre (3/14)", "Sistematización de resultados de talleres y consolidación de informe de sustentación."),
    ("Control de Repositorio", "Etiqueta formal v2.36.0 con historial íntegro de commits y ramas organizadas (main, auditing_and_refactoring).")
]
add_bullets_box(s6, Inches(6.9), Inches(3.65), Inches(5.5), Inches(2.65), s6_bullets_right, font_size=10.2)

# =============================================================
# SLIDE 7: ARQUITECTURA TÉCNICA Y STACK TECNOLÓGICO
# =============================================================
s7 = prs.slides[6]
setup_header(s7, "6. Arquitectura del Sistema", "Clean Architecture y Stack Tecnológico de Vanguardia")

add_card(s7, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s7, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "PATRONES Y ARQUITECTURA LIMPIA (CLEAN ARCHITECTURE)")

s7_arch = [
    ("Capa de Presentación (UI)", "Widgets declarativos en Flutter, gestión reactiva de estado con Provider / ChangeNotifier, navegación declarativa y adaptación Edge-to-Edge."),
    ("Capa de Dominio (Core)", "Entidades puras de negocio (Treatment, Medication, Caregiver), casos de uso desacoplados y contratos abstractos de repositorio."),
    ("Capa de Datos (Data Layer)", "Patrón Repository y Patrón Result funcional para control tipado de éxito/fallo sin excepciones descontroladas en tiempo de ejecución."),
    ("Persistencia Híbrida Offline-First", "Base de datos local SQLite para operatividad total en zonas rurales sin internet, con sincronización automática hacia Cloud Firestore al recuperar señal.")
]
add_bullets_box(s7, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s7_arch, font_size=10.5)

add_card(s7, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s7, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "STACK TECNOLÓGICO Y SERVICIOS INTEGRADOS")

s7_stack = [
    ("Framework Móvil", "Flutter 3.x & Dart 3.x (Compilación nativa ARM64, Sound Null Safety y alto rendimiento a 60 FPS)."),
    ("Backend & Base de Datos", "Google Firebase: Firebase Authentication (OAuth/Email), Cloud Firestore con reglas de seguridad estrictas (firestore.rules)."),
    ("Almacenamiento Multimedia", "Cloudinary CDN para almacenamiento seguro, compresión y entrega optimizada de imágenes de medicamentos."),
    ("Inteligencia Artificial Multimodal", "Groq LPU Cloud: Modelos LLaMA 3.3 70B (asistente Midi), Qwen 2.5-VL (extracción OCR de recetas) y Whisper v3 (reconocimiento de voz)."),
    ("Servicios de Sistema Operativo", "Android AlarmManager Plus (SCHEDULE_EXACT_ALARM), home_widget para escritorio y MapLibre GL para geolocalización.")
]
add_bullets_box(s7, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s7_stack, font_size=10.5)

# =============================================================
# SLIDE 8: AVANCE TÉCNICO: ALARMAS NATIVAS Y MIDI AI (Criterio 3 - 20%)
# =============================================================
s8 = prs.slides[7]
setup_header(s8, "7. Avance Técnico e Innovación", "Motor de Alarmas de Hardware y Asistente Inteligente Midi AI")

add_card(s8, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s8, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "MOTOR DE ALARMAS DE PANTALLA COMPLETA (ANDROID)")

s8_alarms = [
    ("Superación del Doze Mode", "Las apps convencionales fallan cuando el sistema suspende procesos. MediTime implementa AlarmRingingPage con Intents de pantalla completa que despiertan el teléfono bloqueado."),
    ("AlarmManager Exacto", "Uso del permiso de hardware SCHEDULE_EXACT_ALARM con canales de notificación de prioridad máxima e interrupción de No Molestar."),
    ("RebootBroadcastReceiver", "Servicio nativo que intercepta el arranque del sistema (ACTION_BOOT_COMPLETED) y reprograma todas las alarmas sin que el usuario deba abrir la app."),
    ("Acciones en Segundo Plano", "Botones directos en pantalla ('Tomar', 'Posponer 10 min', 'Omitir') que descuentan automáticamente el stock en inventario y registran la adherencia.")
]
add_bullets_box(s8, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s8_alarms, font_size=10.5)

add_card(s8, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s8, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "ASISTENTE CONVERSACIONAL EN EL BORDE (MIDI AI)")

s8_midi = [
    ("Inferencia Ultrarrápida (<1.2s)", "Motor Groq LPU que garantiza latencias casi instantáneas en respuestas conversacionales complejas."),
    ("Interacción por Voz Bidireccional", "Entrada por reconocimiento de voz (Whisper v3) y respuesta auditiva mediante síntesis de texto a voz (flutter_tts) para adultos mayores."),
    ("Tool Calling / Function Execution", "Midi consulta la base de datos local del usuario para responder: dosis pendientes, horarios, adherencia semanal y dudas sobre interacciones."),
    ("Seguridad Clínica y Empatía", "Validación contra contraindicaciones comunes y diálogo alineado con los valores del MEDIT: libre, autónomo y responsable.")
]
add_bullets_box(s8, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s8_midi, font_size=10.5)

# =============================================================
# SLIDE 9: AVANCE TÉCNICO: ECOSISTEMA MULTIPERFIL Y HERRAMIENTAS
# =============================================================
s9 = prs.slides[8]
setup_header(s9, "8. Avance Técnico y Funcional", "Ecosistema Multiperfil, Visión Artificial OCR y Herramientas Móviles")

add_card(s9, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s9, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "ECOSISTEMA MULTIPERFIL: CUIDADOR & VETERINARIA")

s9_multi = [
    ("Modo Cuidador (Caregiver Mode)", "Supervisión centralizada de múltiples pacientes dependientes (adultos mayores, niños). Paleta visual diferenciada (morado pastel) para evitar confusiones de contexto clínico."),
    ("Bitácora de Cumplimiento", "Monitoreo en tiempo real del estado de tomas de cada dependiente y alertas proactivas ante desabastecimiento de medicamentos en el hogar."),
    ("Modo Animales (Veterinaria)", "Gestión posológica de tratamientos para mascotas y animales de granja, con dosificaciones veterinarias y paleta independiente verde crema."),
    ("Separación Estricta de Datos", "Almacenamiento segregado en SQLite/Firestore para garantizar la privacidad y orden de los historiales médicos.")
]
add_bullets_box(s9, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s9_multi, font_size=10.5)

add_card(s9, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s9, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "VISIÓN ARTIFICIAL, WIDGETS Y REPORTES CLÍNICOS")

s9_tools = [
    ("Digitalización OCR de Recetas", "Captura fotográfica de fórmulas médicas impresas o manuscritas. Extracción semántica automática de medicamento, dosis, horario y duración con Qwen Vision."),
    ("Widgets de Escritorio para Android", "Integración con home_widget que muestra en la pantalla de inicio del celular la próxima toma y estado del tratamiento sin abrir la aplicación."),
    ("Geolocalizador de Farmacias", "Mapa interactivo integrado (MapLibre GL y GPS) para ubicar droguerías y puntos de dispensación cercanos en los municipios del Valle de Ubaté."),
    ("Reportes Médicos en PDF", "Exportación de informes clínicos certificados con gráficos vectoriales (fl_chart) para presentar en citas médicas de control.")
]
add_bullets_box(s9, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s9_tools, font_size=10.5)

# =============================================================
# SLIDE 10: EVALUACIÓN DE CALIDAD DE SOFTWARE ISO/IEC 25010 (Criterio 2 - 25%)
# =============================================================
s10 = prs.slides[9]
setup_header(s10, "9. Aseguramiento de Calidad", "Evaluación Rigurosa de Calidad de Software Bajo Norma ISO/IEC 25010")

coords = [
    (Inches(0.8), Inches(1.85), Inches(5.6), Inches(2.2)),
    (Inches(6.8), Inches(1.85), Inches(5.7), Inches(2.2)),
    (Inches(0.8), Inches(4.2), Inches(5.6), Inches(2.2)),
    (Inches(6.8), Inches(4.2), Inches(5.7), Inches(2.2))
]

# 1. Adecuación Funcional
add_card(s10, coords[0][0], coords[0][1], coords[0][2], coords[0][3])
add_card_header(s10, coords[0][0], coords[0][1], coords[0][2], Inches(0.36), "1. ADECUACIÓN FUNCIONAL (COMPLETITUD Y CORRECCIÓN)")
add_kpi_badge(s10, Inches(1.0), Inches(2.32), Inches(1.8), Inches(0.95), "194", "Tests Aprobados", "100% éxito flutter test")
add_bullets_box(s10, Inches(2.9), Inches(2.25), Inches(3.4), Inches(1.7), [
    ("Completitud", "100% de capacidades críticas operativas."),
    ("Suite Automatizada", "194 pruebas de widgets, casos de uso y repositorios con 0 fallos.")
], font_size=10)

# 2. Fiabilidad y Tolerancia a Fallos
add_card(s10, coords[1][0], coords[1][1], coords[1][2], coords[1][3])
add_card_header(s10, coords[1][0], coords[1][1], coords[1][2], Inches(0.36), "2. FIABILIDAD Y TOLERANCIA A FALLOS (RESILIENCIA)")
add_kpi_badge(s10, Inches(7.0), Inches(2.32), Inches(1.8), Inches(0.95), "100%", "Alarmas Activas", "Resistencia a reboot/Doze")
add_bullets_box(s10, Inches(8.9), Inches(2.25), Inches(3.5), Inches(1.7), [
    ("Persistencia Offline", "Operatividad completa sin pérdida de datos en modo avión."),
    ("Reactivación Automática", "100% de alarmas reprogramadas tras reinicio del teléfono.")
], font_size=10)

# 3. Usabilidad y Accesibilidad
add_card(s10, coords[2][0], coords[2][1], coords[2][2], coords[2][3])
add_card_header(s10, coords[2][0], coords[2][1], coords[2][2], Inches(0.36), "3. USABILIDAD Y ACCESIBILIDAD (EXPERIENCIA DE USUARIO)")
add_kpi_badge(s10, Inches(1.0), Inches(4.67), Inches(1.8), Inches(0.95), "88.5", "Puntaje SUS / 100", "Grado A - Nivel Excelente")
add_bullets_box(s10, Inches(2.9), Inches(4.6), Inches(3.4), Inches(1.7), [
    ("Modo Simplificado", "Tipografía agrandada y controles táctiles asistivos para adultos mayores."),
    ("Inclusión Auditiva", "Soporte de lectura por voz TTS y comandos naturales Whisper.")
], font_size=10)

# 4. Eficiencia de Desempeño
add_card(s10, coords[3][0], coords[3][1], coords[3][2], coords[3][3])
add_card_header(s10, coords[3][0], coords[3][1], coords[3][2], Inches(0.36), "4. EFICIENCIA DE DESEMPEÑO (VELOCIDAD Y RECURSOS)")
add_kpi_badge(s10, Inches(7.0), Inches(4.67), Inches(1.8), Inches(0.95), "<1.2s", "Latencia IA Groq", "Inferencia en el borde")
add_bullets_box(s10, Inches(8.9), Inches(4.6), Inches(3.5), Inches(1.7), [
    ("Arranque en Frío", "Inicio del aplicativo en < 1.5 segundos."),
    ("Consumo de Batería", "Impacto mínimo en segundo plano (< 2% consumo/día en reposo).")
], font_size=10)

# =============================================================
# SLIDE 11: ACCIÓN DE DEVOLUCIÓN AL TERRITORIO Y TRANSFERENCIA (Criterio 1 y 2 - 40%)
# =============================================================
s11 = prs.slides[10]
setup_header(s11, "10. Devolución al Territorio", "Estrategia de Transferencia Comunitaria e Impacto Social en Ubaté")

add_card(s11, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s11, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "TALLERES DE FORMACIÓN Y TRANSFERENCIA SOCIAL")

s11_workshops = [
    ("Taller 1: 'Tu Salud en Tus Manos'", "Capacitación a pacientes crónicos y adultos mayores en registro intuitivo, escaneo de fórmulas y uso del asistente por voz Midi AI."),
    ("Taller 2: 'Supervisión Segura del Tratamiento'", "Formación a cuidadores familiares en el uso del Modo Cuidador, alertas de reposición de medicamentos y gestión multi-dependiente."),
    ("Taller 3: 'Diálogo Informado con el Médico'", "Instrucción sobre generación de reportes clínicos certificados en PDF para llevar a las citas hospitalarias de control."),
    ("Acompañamiento Personalizado", "Resolución de barreras operativas y ajustes de accesibilidad visual y auditiva directamente con los usuarios de la comunidad.")
]
add_bullets_box(s11, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s11_workshops, font_size=10.5)

add_card(s11, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s11, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "ENTREGABLES TANGIBLES Y CAMBIO EN EL TERRITORIO")

s11_impact = [
    ("Cartillas Didácticas Impresas", "Material pedagógico en gran formato con ilustraciones a color y lenguaje llano, garantizando acceso a pacientes sin destrezas tecnológicas previas."),
    ("Distribución Libre del APK", "Entrega del paquete instalador firmado (MediTime Release) de uso gratuito y sin anuncios publicitarios invasivos."),
    ("Compilación Oficial C3", "Transferencia al programa académico de los Manuales de Usuario, Técnico y Plan de Sostenibilidad con licencia de código abierto."),
    ("Transformación del Territorio", "Reducción palpable del olvido posológico en los hogares intervenidos, mayor empoderamiento del paciente y mejor comunicación médico-paciente.")
]
add_bullets_box(s11, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s11_impact, font_size=10.5)

# =============================================================
# SLIDE 12: GOBERNANZA, MANTENIMIENTO Y PLAN DE SOSTENIBILIDAD (Criterio 2 - 25%)
# =============================================================
s12 = prs.slides[11]
setup_header(s12, "11. Plan de Sostenibilidad", "Estructura de Gobernanza, Modelo de Costos $0 USD y Continuidad")

add_card(s12, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s12, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "GOBERNANZA Y ASIGNACIÓN DE ROLES (MATRIZ RACI)")

s12_gov = [
    ("Comité Gestor UDEC (Seccional Ubaté)", "Responsable del seguimiento institucional, articulación comunitaria y preservación del proyecto en el repositorio académico."),
    ("Líder de Desarrollo y Arquitectura", "Jorge Eliecer Delgado Cortés: Custodia del repositorio de código, despliegue de versiones, administración de Firebase y API Groq."),
    ("Líder de Calidad y Transferencia", "Johan Alexander Arévalo Contreras: Soporte operativo a usuarios piloto, auditoría de métricas de calidad y coordinación comunitaria."),
    ("Alianzas Estratégicas Locales", "Vinculación con redes de salud y farmacias para difusión del aplicativo y soporte a pacientes crónicos del municipio.")
]
add_bullets_box(s12, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s12_gov, font_size=10.5)

add_card(s12, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s12, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "MODELO DE COSTOS Y CONTINUIDAD OPERATIVA")

s12_fin = [
    ("Infraestructura de Costos Iniciales en $0 USD", "Operación garantizada sobre tiers gratuitos: Firebase Spark (50k lecturas/día), Cloudinary Free (25 créditos/mes) y Groq Cloud Developer Tier."),
    ("Arquitectura de Fallback Inteligente", "Si las cuotas de IA cloud se saturan, el sistema conmuta automáticamente a modelos ligeros o mantiene las alarmas y registros 100% operativos de forma local."),
    ("Plan de Mantenimiento Preventivo", "Ciclos trimestrales de actualización de librerías Flutter, verificación de parches de seguridad Android y copias de respaldo de datos."),
    ("Escalabilidad Futura", "Modelo freemium no invasivo proyectado para funciones avanzadas sin comprometer la gratuidad de los servicios esenciales de salud.")
]
add_bullets_box(s12, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s12_fin, font_size=10.5)

# =============================================================
# SLIDE 13: PRODUCTO ACADÉMICO FINAL Y DIVULGACIÓN CIENTÍFICA (Criterio 4 - 10%)
# =============================================================
s13 = prs.slides[12]
setup_header(s13, "12. Producto Académico Final", "Artículo de Investigación Aplicada y Revista Científica Objetivo")

add_card(s13, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s13, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "ESTRUCTURA DEL ARTÍCULO CIENTÍFICO CONSOLIDADO")

s13_paper = [
    ("Título Oficial del Artículo", "'MediTime: Plataforma Móvil Inteligente para la Optimización de la Adherencia Terapéutica en Poblaciones Crónicas mediante Visión Artificial y Asistencia Conversacional en el Borde'."),
    ("Autores", "Jorge Eliecer Delgado Cortés & Johan Alexander Arévalo Contreras."),
    ("Metodología IMRyD", "Introducción (crisis de no adherencia OMS), Metodología (Clean Architecture e ISO/IEC 25010), Resultados técnicos y evaluación comunitaria en Ubaté."),
    ("Hallazgos Principales", "Demostración de que la IA multimodal combinada con alarmas de hardware nativas incrementa la puntualidad de tomas y reduce los errores de posología.")
]
add_bullets_box(s13, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s13_paper, font_size=10.5)

add_card(s13, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s13, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "REVISTA INDEXADA OBJETIVO (MINCIENCIAS / SCOPUS)")

s13_journal = [
    ("Revista Seleccionada", "Revista UIS Ingenierías (Universidad Industrial de Santander)."),
    ("Indexación y Reconocimiento", "Publindex MinCiencias (Categoría B) • Scopus • SciELO • Redalyc • DOAJ."),
    ("Línea Temática Editorial", "Ingeniería de Software, Informática Médica, Salud Digital (mHealth) y Aplicaciones de Inteligencia Artificial."),
    ("Alternativa Institucional", "Revista Facultad de Ingeniería UPTC (ISSN 0121-1129 / e-ISSN 2357-5328), indexada en Publindex y enfocada en impacto regional y tecnológico."),
    ("Modalidad de Grado", "Cumplimiento riguroso de la modalidad de Proyecto de Grado / PGC con producto de divulgación científica formal.")
]
add_bullets_box(s13, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s13_journal, font_size=10.5)

# =============================================================
# SLIDE 14: MINUTO EN INGLÉS: MAIN CONCLUSIONS (Criterio 7 - 5%)
# =============================================================
s14 = prs.slides[13]
setup_header(s14, "13. Minuto en Inglés (English Minute)", "Main Technical & Territorial Conclusions (60-Second Presentation)")

eng_boxes = [
    (Inches(0.8), Inches(1.85), Inches(11.7), Inches(1.05),
     "1. Overcoming the Adherence Barrier in the Territory",
     "MediTime successfully addresses the 59% treatment non-adherence rate reported by the WHO. By deploying an accessible mobile platform tailored for chronic patients in the Province of Ubaté, the project empowers individuals to achieve therapeutic compliance and informed medical self-management."),
    
    (Inches(0.8), Inches(2.98), Inches(11.7), Inches(1.05),
     "2. Hardware-Level Resilient Alarming Architecture",
     "Through native full-screen intents and persistent reboot broadcast receivers in Android, the platform guarantees 100% alarm reliability, successfully bypassing aggressive manufacturer power-saving restrictions and the Android Doze Mode."),
    
    (Inches(0.8), Inches(4.11), Inches(11.7), Inches(1.05),
     "3. Multimodal Edge AI & Inclusive Multi-profile Ecosystem",
     "The integration of vision-assisted OCR for prescription scanning and the conversational Midi AI assistant powered by Groq LPU minimizes data entry friction, while the specialized Caregiver and Veterinary modes expand social healthcare coverage."),
    
    (Inches(0.8), Inches(5.24), Inches(11.7), Inches(1.15),
     "4. Sustainable Community Transfer under the MEDIT Paradigm",
     "The initiative fulfills the university's mission through effective knowledge transfer: delivering tangible training workshops, printed visual guides, open-source software, and a zero-cost operational sustainability model that guarantees long-term public health benefits.")
]

for left, top, width, height, heading, body in eng_boxes:
    add_card(s14, left, top, width, height, bg_color=COLOR_ACCENT_BG, border_color=COLOR_ACCENT_BORDER)
    tb = s14.shapes.add_textbox(left + Inches(0.15), top + Inches(0.08), width - Inches(0.3), height - Inches(0.16))
    ttf = tb.text_frame
    ttf.word_wrap = True
    ttf.margin_left = ttf.margin_top = ttf.margin_right = ttf.margin_bottom = 0
    p = ttf.paragraphs[0]
    p.text = heading
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(2)
    p2 = ttf.add_paragraph()
    p2.text = body
    p2.font.size = Pt(9.8)
    p2.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 15: CONCLUSIONES GENERALES, LIMITACIONES Y TRABAJO FUTURO (Criterio 4 - 10%)
# =============================================================
s15 = prs.slides[14]
setup_header(s15, "14. Conclusiones y Trabajo Futuro", "Balance de Ingeniería, Limitaciones y Perspectivas Futuras")

add_card(s15, Inches(0.8), Inches(1.85), Inches(5.6), Inches(4.55))
add_card_header(s15, Inches(0.8), Inches(1.85), Inches(5.6), Inches(0.42), "CONCLUSIONES TÉCNICAS Y METODOLÓGICAS")

s15_concl = [
    ("Cumplimiento del 100% de Metas", "Se culminaron con éxito todos los productos mínimos exigidos para el Cierre de Noveno Semestre (C3), garantizando una solución móvil robusta, usable e integrable."),
    ("Alta Madurez de Software", "La aplicación alcanzó un puntaje SUS de 88.5/100, 194 pruebas automatizadas con 0 defectos y latencias de inferencia de IA inferiores a 1.2 segundos."),
    ("Impacto Social Comprobado", "La articulación con el modelo MEDIT y los talleres en Ubaté demostraron que la tecnología contextualizada reduce el olvido posológico y dignifica el cuidado del paciente."),
    ("Sostenibilidad Operativa", "El diseño de arquitectura desacoplada y costos cloud en cero garantiza que el proyecto permanezca disponible para la comunidad sin requerir cobros.")
]
add_bullets_box(s15, Inches(0.9), Inches(2.38), Inches(5.4), Inches(3.9), s15_concl, font_size=10.5)

add_card(s15, Inches(6.8), Inches(1.85), Inches(5.7), Inches(4.55))
add_card_header(s15, Inches(6.8), Inches(1.85), Inches(5.7), Inches(0.42), "LIMITACIONES DETECTADAS Y TRABAJO FUTURO")

s15_future = [
    ("Limitaciones Identificadas", "1) Dependencia de conectividad a internet para los servicios de IA generativa y visión OCR en la nube.\n2) Restricciones agresivas y no estandarizadas de batería impuestas por fabricantes como Xiaomi (MIUI) y Huawei (EMUI).\n3) Caligrafía médica manuscrita extrema que requiere revisión humana."),
    ("Línea Futura 1: Modelos Offline (SLM)", "Integración de modelos de lenguaje pequeños (Small Language Models) ejecutados directamente en el dispositivo móvil mediante ONNX Runtime y TFLite."),
    ("Línea Futura 2: Integración IoT Biomédica", "Conectividad Bluetooth Low Energy (BLE) con tensiómetros, glucómetros y pastilleros inteligentes para registro posológico automático."),
    ("Línea Futura 3: Analítica Predictiva", "Algoritmos locales de Machine Learning para predecir el riesgo de deserción farmacológica y generar alertas tempranas a los cuidadores.")
]
add_bullets_box(s15, Inches(6.9), Inches(2.38), Inches(5.5), Inches(3.9), s15_future, font_size=10.2)

# =============================================================
# SLIDE 16: REFERENCIAS BIBLIOGRÁFICAS (Norma APA 7ma Edición)
# =============================================================
s16 = prs.slides[15]
setup_header(s16, "15. Referencias Bibliográficas", "Fuentes de Información, Literatura Científica y Marco Normativo")

add_card(s16, Inches(0.8), Inches(1.85), Inches(11.7), Inches(4.55))
add_card_header(s16, Inches(0.8), Inches(1.85), Inches(11.7), Inches(0.42), "FUENTES CONSULTADAS Y REFERENCIADAS (NORMA APA 7ma EDICIÓN)")

s16_refs = [
    ("Cardona Mecia, M. L. (2023)", "Desarrollo del prototipo de una aplicación móvil para el control de medicamentos y gestión de turnos para agilizar la atención en centros de dispensación. Universidad de Antioquia."),
    ("Congreso de la República de Colombia (2012)", "Ley Estatutaria 1581 de 2012: Disposiciones generales para la protección de datos personales. Diario Oficial No. 48.587."),
    ("Domenech, I. M. (2021)", "Aplicaciones para la gestión de la medicación de las personas mayores: Una revisión bibliográfica. Universitat Oberta de Catalunya."),
    ("ISO/IEC (2011)", "Systems and software engineering — Systems and software Quality Requirements and Evaluation (SQuaRE) — System and software quality models (ISO/IEC 25010:2011)."),
    ("Lara Castro, M., López Huerta, F., & Herrera May, A. L. (2018)", "Aplicaciones médicas en dispositivos móviles con enfoque en salud pública. Interconectando Saberes, 6(1), 101-109."),
    ("Mather, T., Kumaraswamy, S., & Latif, S. (2009)", "Cloud Security and Privacy: An Enterprise Perspective on Risks and Compliance. O'Reilly Media."),
    ("Organización Mundial de la Salud (2003)", "Adherence to long-term therapies: Evidence for action. Organización Mundial de la Salud, Ginebra."),
    ("Organización Mundial de la Salud (2023)", "Global report on hypertension: The race against a silent killer. WHO Press, Ginebra."),
    ("Universidad de Cundinamarca (2020)", "Modelo Educativo Digital Transmoderno (MEDIT): Lineamientos pedagógicos e institucionales. Editorial UDEC, Fusagasugá.")
]
add_bullets_box(s16, Inches(0.95), Inches(2.35), Inches(11.4), Inches(3.95), s16_refs, font_size=9.8)

# =============================================================
# SLIDE 17: CIERRE INSTITUCIONAL (PLANTILLA V2 SLIDE 5)
# =============================================================
s17 = prs.slides[16]

for shape in list(s17.shapes):
    if shape.has_text_frame:
        sp = shape._element
        sp.getparent().remove(sp)

t_box = s17.shapes.add_textbox(Inches(1.5), Inches(3.1), Inches(10.3), Inches(0.9))
ttf = t_box.text_frame
ttf.word_wrap = True
tp = ttf.paragraphs[0]
tp.text = "¡MUCHAS GRACIAS!"
tp.font.size = Pt(36)
tp.font.bold = True
tp.font.color.rgb = COLOR_TEXT_WHITE
tp.alignment = PP_ALIGN.CENTER

sub_box = s17.shapes.add_textbox(Inches(1.5), Inches(4.05), Inches(10.3), Inches(2.3))
stf = sub_box.text_frame
stf.word_wrap = True

sp1 = stf.paragraphs[0]
sp1.text = "Espacio para Sustentación y Preguntas del Jurado Evaluador"
sp1.font.size = Pt(17)
sp1.font.bold = True
sp1.font.color.rgb = RGBColor(187, 247, 208)
sp1.alignment = PP_ALIGN.CENTER
sp1.space_after = Pt(10)

sp2 = stf.add_paragraph()
sp2.text = "DESARROLLO DE UNA APLICACIÓN MÓVIL PARA LA GESTIÓN DE TRATAMIENTOS MÉDICOS (MEDITIME)"
sp2.font.size = Pt(12)
sp2.font.bold = True
sp2.font.color.rgb = COLOR_TEXT_WHITE
sp2.alignment = PP_ALIGN.CENTER
sp2.space_after = Pt(4)

sp3 = stf.add_paragraph()
sp3.text = "Creadores de Oportunidades: Jorge Eliecer Delgado Cortés & Johan Alexander Arévalo Contreras\nCiclo III — Noveno Semestre (2026-2) • Programa de Ingeniería de Sistemas y Computación\nUniversidad de Cundinamarca — Seccional Ubaté"
sp3.font.size = Pt(10.5)
sp3.font.color.rgb = RGBColor(209, 213, 219)
sp3.alignment = PP_ALIGN.CENTER

# Save presentation
prs.save(OUT_PPTX)
print(f"Presentation saved successfully to: {OUT_PPTX}")
print(f"Total slides in deck: {len(prs.slides)}")

# Convert to PDF using PowerPoint COM
print("Converting PPTX to PDF via PowerPoint COM...")
ppt_app = win32com.client.Dispatch('PowerPoint.Application')
pres_path = os.path.abspath(OUT_PPTX)
pdf_path = os.path.abspath(OUT_PDF)

pres = ppt_app.Presentations.Open(pres_path, WithWindow=False)
pres.SaveAs(pdf_path, 32) # 32 = ppSaveAsPDF

# Also re-export preview PNGs
out_dir = os.path.abspath(r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\slides_preview')
for i in range(1, pres.Slides.Count + 1):
    slide = pres.Slides(i)
    png_path = os.path.join(out_dir, f'slide_{i:02d}.png')
    slide.Export(png_path, 'PNG', 1920, 1080)

pres.Close()
ppt_app.Quit()

print(f"PDF exported successfully to: {OUT_PDF}")
print(f"File size: {os.path.getsize(OUT_PDF)} bytes")
