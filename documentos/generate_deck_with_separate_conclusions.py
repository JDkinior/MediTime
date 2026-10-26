import os
import win32com.client
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

BASE_TEMPLATE = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\clean_template_13.pptx'
OUT_PPTX = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\C3_Desarrollo de una aplicacion movil para la gestion de tratamientos medicos_Delgado&Arevalo.pptx'
OUT_PDF = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\C3_Desarrollo de una aplicacion movil para la gestion de tratamientos medicos_Delgado&Arevalo.pdf'

IMG_KANBAN = r'c:\Users\degkp\Documents\Proyectos\MediTime\documentos\extracted_assets\prev_pptx_00.png'
IMG_HOME = r'c:\Users\degkp\Downloads\Mobile Devices\Screenshot_20261021_130452.jpg'
IMG_QR = r'c:\Users\degkp\Documents\Proyectos\MediTime Page\images\qr-code.png'

prs = Presentation(BASE_TEMPLATE)

# Institutional Color Palette
COLOR_UDEC_GREEN_DARK = RGBColor(0, 85, 40)      # #005528
COLOR_UDEC_GREEN = RGBColor(0, 114, 54)          # #007236
COLOR_UDEC_GREEN_LIGHT = RGBColor(235, 246, 238) # #EBF6EE
COLOR_TEXT_PRIMARY = RGBColor(30, 41, 59)        # Slate 800
COLOR_TEXT_MUTED = RGBColor(100, 116, 139)       # Slate 500
COLOR_TEXT_WHITE = RGBColor(255, 255, 255)
COLOR_CARD_BG = RGBColor(255, 255, 255)
COLOR_CARD_BORDER = RGBColor(218, 225, 231)
COLOR_ACCENT_BG = RGBColor(240, 253, 244)
COLOR_ACCENT_BORDER = RGBColor(134, 239, 172)
COLOR_HIGHLIGHT_RED = RGBColor(185, 28, 28)

def setup_header(slide, category, title):
    cat_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.40), Inches(7.5), Inches(0.32))
    ctf = cat_box.text_frame
    ctf.word_wrap = True
    ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
    cp = ctf.paragraphs[0]
    cp.text = category.upper()
    cp.font.size = Pt(11)
    cp.font.bold = True
    cp.font.color.rgb = COLOR_UDEC_GREEN
    
    title_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.95), Inches(11.7), Inches(0.65))
    ttf = title_box.text_frame
    ttf.word_wrap = True
    ttf.margin_left = ttf.margin_top = ttf.margin_right = ttf.margin_bottom = 0
    tp = ttf.paragraphs[0]
    tp.text = title
    tp.font.size = Pt(21)
    tp.font.bold = True
    tp.font.color.rgb = COLOR_UDEC_GREEN_DARK

def add_card(slide, left, top, width, height, bg_color=COLOR_CARD_BG, border_color=COLOR_CARD_BORDER):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = bg_color
    shape.line.color.rgb = border_color
    shape.line.width = Pt(1.3)
    return shape

# =============================================================
# SLIDE 1: PORTADA INSTITUCIONAL
# =============================================================
s1 = prs.slides[0]
for shape in list(s1.shapes):
    if shape.name in ['CuadroTexto 8', 'CuadroTexto 10']:
        sp = shape._element
        sp.getparent().remove(sp)

title_box = s1.shapes.add_textbox(Inches(0.8), Inches(1.65), Inches(6.0), Inches(2.6))
tf = title_box.text_frame
tf.word_wrap = True
tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

p_cat = tf.paragraphs[0]
p_cat.text = "PROYECTO DE GESTIÓN DEL CONOCIMIENTO (PGC) • CICLO III"
p_cat.font.size = Pt(11.5)
p_cat.font.bold = True
p_cat.font.color.rgb = COLOR_UDEC_GREEN
p_cat.space_after = Pt(6)

p_title = tf.add_paragraph()
p_title.text = "MEDITIME: GESTIÓN INTEGRAL DE RECETAS MÉDICAS Y CONTROL DE PRESCRIPCIONES"
p_title.font.size = Pt(17)
p_title.font.bold = True
p_title.font.color.rgb = COLOR_UDEC_GREEN_DARK
p_title.space_after = Pt(6)

p_sub = tf.add_paragraph()
p_sub.text = "Aplicación Móvil Asistida por IA (v2.37.0) y Plataforma Web Oficial"
p_sub.font.size = Pt(13)
p_sub.font.bold = True
p_sub.font.color.rgb = COLOR_TEXT_MUTED
p_sub.space_after = Pt(4)

p_sub2 = tf.add_paragraph()
p_sub2.text = "Sustentación de Segunda Entrega • Noveno Semestre (2026-2)"
p_sub2.font.size = Pt(11.5)
p_sub2.font.color.rgb = COLOR_TEXT_PRIMARY

meta_box = s1.shapes.add_textbox(Inches(0.8), Inches(4.55), Inches(6.0), Inches(2.2))
mtf = meta_box.text_frame
mtf.word_wrap = True
mtf.margin_left = mtf.margin_top = mtf.margin_right = mtf.margin_bottom = 0

p1 = mtf.paragraphs[0]
p1.text = "Creadores de Oportunidades (Autores):"
p1.font.size = Pt(12)
p1.font.bold = True
p1.font.color.rgb = COLOR_UDEC_GREEN_DARK

p2 = mtf.add_paragraph()
p2.text = "• Johan Alexander Arévalo Contreras\n• Jorge Eliecer Delgado Cortés"
p2.font.size = Pt(12)
p2.font.color.rgb = COLOR_TEXT_PRIMARY
p2.space_after = Pt(8)

p3 = mtf.add_paragraph()
p3.text = "Programa de Ingeniería de Sistemas • Seccional Ubaté\nUniversidad de Cundinamarca (Septiembre - Octubre 2026)"
p3.font.size = Pt(11)
p3.font.color.rgb = COLOR_TEXT_MUTED

# =============================================================
# SLIDE 2: DEFINICIÓN Y FORMULACIÓN DEL PROBLEMA
# =============================================================
s2 = prs.slides[1]
setup_header(s2, "1. Definición del Problema", "Incumplimiento en Prescripciones y Brecha en Salud")

add_card(s2, Inches(0.8), Inches(1.9), Inches(5.2), Inches(4.75), bg_color=RGBColor(254, 242, 242), border_color=COLOR_HIGHLIGHT_RED)
stf = s2.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(4.8), Inches(4.3)).text_frame
stf.word_wrap = True

sp1 = stf.paragraphs[0]
sp1.text = "~50%"
sp1.font.size = Pt(64)
sp1.font.bold = True
sp1.font.color.rgb = COLOR_HIGHLIGHT_RED
sp1.alignment = PP_ALIGN.CENTER

sp2 = stf.add_paragraph()
sp2.text = "de pacientes con medicación a largo plazo no toman sus fármacos según lo prescrito."
sp2.font.size = Pt(15)
sp2.font.bold = True
sp2.font.color.rgb = COLOR_TEXT_PRIMARY
sp2.alignment = PP_ALIGN.CENTER
sp2.space_after = Pt(12)

sp3 = stf.add_paragraph()
sp3.text = "Causas críticas identificadas:"
sp3.font.size = Pt(13)
sp3.font.bold = True
sp3.font.color.rgb = COLOR_HIGHLIGHT_RED

sp4 = stf.add_paragraph()
sp4.text = "• Olvido recurrente en horarios de tomas.\n• Pérdida o deterioro de fórmulas físicas en papel.\n• Complejidad por polifarmacia en el mismo hogar.\n• Dificultad para validar vigencia y dosis en zonas de Cundinamarca."
sp4.font.size = Pt(11.5)
sp4.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s2, Inches(6.3), Inches(1.9), Inches(6.2), Inches(4.75))
rtf = s2.shapes.add_textbox(Inches(6.5), Inches(2.1), Inches(5.8), Inches(4.3)).text_frame
rtf.word_wrap = True

rp1 = rtf.paragraphs[0]
rp1.text = "⚠️ Consecuencias Clínicas Directas"
rp1.font.size = Pt(16)
rp1.font.bold = True
rp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
rp1.space_after = Pt(8)

rp2 = rtf.add_paragraph()
rp2.text = "• Empeoramiento progresivo de patologías base.\n• Aparición de resistencia farmacológica.\n• Riesgo severo de interacciones medicamentosas adversas.\n• Reingresos hospitalarios no planificados a urgencias."
rp2.font.size = Pt(12)
rp2.font.color.rgb = COLOR_TEXT_PRIMARY
rp2.space_after = Pt(14)

rp3 = rtf.add_paragraph()
rp3.text = "❓ Formulación de la Pregunta Problema"
rp3.font.size = Pt(15)
rp3.font.bold = True
rp3.font.color.rgb = COLOR_UDEC_GREEN_DARK
rp3.space_after = Pt(6)

rp4 = rtf.add_paragraph()
rp4.text = '"¿Cómo puede una aplicación móvil multiplataforma dotada de visión artificial, asistente de voz e inteligencia en la nube optimizar la gestión de recetas médicas y prevenir errores en Cundinamarca?"'
rp4.font.size = Pt(12)
rp4.font.bold = True
rp4.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 3: JUSTIFICACIÓN E IMPACTO
# =============================================================
s3 = prs.slides[2]
setup_header(s3, "2. Justificación", "Evolución Digital, Inclusión y Seguridad Farmacológica")

add_card(s3, Inches(0.8), Inches(1.9), Inches(5.6), Inches(4.75))
jtf1 = s3.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(5.2), Inches(4.3)).text_frame
jtf1.word_wrap = True

jp1 = jtf1.paragraphs[0]
jp1.text = "💡 Valor Técnico Sustancial"
jp1.font.size = Pt(16)
jp1.font.bold = True
jp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
jp1.space_after = Pt(8)

j_items1 = [
    ("Transición Analógica a Digital", "Elimina la manipulación de fórmulas físicas de papel susceptibles a pérdidas."),
    ("Visión Artificial Multimodal", "Interpretación y extracción semántica automática de recetas impresas y manuscritas."),
    ("Eliminación de Errores", "Minimiza la fricción y el error humano asociado al digitado manual de posologías complejas."),
    ("Alarmas Nativa de Pantalla Completa", "Disparo puntual sin importar el ahorro de energía (Doze Mode).")
]
for t, d in j_items1:
    p = jtf1.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s3, Inches(6.7), Inches(1.9), Inches(5.8), Inches(4.75), bg_color=COLOR_ACCENT_BG, border_color=COLOR_ACCENT_BORDER)
jtf2 = s3.shapes.add_textbox(Inches(6.9), Inches(2.1), Inches(5.4), Inches(4.3)).text_frame
jtf2.word_wrap = True

jp2 = jtf2.paragraphs[0]
jp2.text = "🌱 Valor Social e Inclusivo"
jp2.font.size = Pt(16)
jp2.font.bold = True
jp2.font.color.rgb = COLOR_UDEC_GREEN_DARK
jp2.space_after = Pt(8)

j_items2 = [
    ("Asistente por Voz Midi AI", "Procesamiento de lenguaje natural y síntesis de voz para personas con dificultades de lectura."),
    ("Accesibilidad Visual WCAG", "Alto contraste, escala tipográfica adaptable y diseño intuitivo."),
    ("Modo Cuidador", "Supervisión unificada de tratamientos para familiares mayores o dependientes."),
    ("Modo Animales", "Módulo veterinario especializado para dosificación y cuidado de mascotas.")
]
for t, d in j_items2:
    p = jtf2.add_paragraph()
    p.text = f"✔ {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 4: OBJETIVOS DEL PROYECTO
# =============================================================
s4 = prs.slides[3]
setup_header(s4, "3. Objetivos del Proyecto", "Objetivo General y Objetivos Específicos Formales")

add_card(s4, Inches(1.0), Inches(1.9), Inches(11.3), Inches(4.75))
otf = s4.shapes.add_textbox(Inches(1.3), Inches(2.1), Inches(10.7), Inches(4.35)).text_frame
otf.word_wrap = True

op1 = otf.paragraphs[0]
op1.text = "🎯 Objetivo General"
op1.font.size = Pt(17)
op1.font.bold = True
op1.font.color.rgb = COLOR_UDEC_GREEN_DARK
op1.space_after = Pt(4)

op2 = otf.add_paragraph()
op2.text = "Desarrollar una aplicación móvil que facilite la gestión integral de tratamientos médicos, permitiendo a los pacientes acceder a sus prescripciones digitalmente, monitorear su dosificación diaria, recibir recordatorios automáticos y mantener un historial clínico actualizado."
op2.font.size = Pt(14)
op2.font.color.rgb = COLOR_TEXT_PRIMARY
op2.space_after = Pt(16)

op3 = otf.add_paragraph()
op3.text = "📋 Objetivos Específicos"
op3.font.size = Pt(17)
op3.font.bold = True
op3.font.color.rgb = COLOR_UDEC_GREEN_DARK
op3.space_after = Pt(8)

doc_objs = [
    "Conceptualizar la aplicación identificando necesidades y requisitos de pacientes.",
    "Investigar sobre aplicaciones de gestión de tratamientos médicos y sus limitaciones actuales.",
    "Diseñar prototipos de interfaz y experiencia intuitivos (dosificación, alertas, historial).",
    "Realizar pruebas de funcionalidad con pacientes reales para evaluar eficacia y usabilidad.",
    "Desarrollar el sistema con autenticación, recordatorios, persistencia e historial detallado."
]
for obj in doc_objs:
    p = otf.add_paragraph()
    p.text = f"• {obj}"
    p.font.size = Pt(12.5)
    p.font.color.rgb = COLOR_TEXT_PRIMARY
    p.space_after = Pt(5)

# =============================================================
# SLIDE 5: MARCO DE REFERENCIA Y LEGAL
# =============================================================
s5 = prs.slides[4]
setup_header(s5, "4. Marco de Referencia y Legal", "Evidencia Científica (mHealth) y Normatividad Colombiana")

add_card(s5, Inches(0.8), Inches(1.9), Inches(5.6), Inches(4.75))
rtf1 = s5.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(5.2), Inches(4.3)).text_frame
rtf1.word_wrap = True

rp1 = rtf1.paragraphs[0]
rp1.text = "📚 Evidencia en Salud Digital (mHealth)"
rp1.font.size = Pt(15.5)
rp1.font.bold = True
rp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
rp1.space_after = Pt(8)

ref_items = [
    ("Eficacia Demostrada (Domenech, 2021)", "Revisiones sistemáticas confirman que el 70% de intervenciones mHealth mejoran significativamente la adherencia y calidad de vida."),
    ("Sistemas Clínicos Expertos", "Antecedentes de IA médica como INFOTOXI y GERISOFT fundamentan la asistencia automatizada."),
    ("Adherencia en Adultos Mayores", "Estudios en Perú y Colombia (Pérez Guevara, 2019; Cardona Mecia, 2023) ratifican que recordatorios móviles reducen olvidos.")
]
for t, d in ref_items:
    p = rtf1.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s5, Inches(6.7), Inches(1.9), Inches(5.8), Inches(4.75))
rtf2 = s5.shapes.add_textbox(Inches(6.9), Inches(2.1), Inches(5.4), Inches(4.3)).text_frame
rtf2.word_wrap = True

rp2 = rtf2.paragraphs[0]
rp2.text = "⚖️ Marco Legal Vigente en Colombia"
rp2.font.size = Pt(15.5)
rp2.font.bold = True
rp2.font.color.rgb = COLOR_UDEC_GREEN_DARK
rp2.space_after = Pt(8)

law_items = [
    ("Ley 1581 de 2012 / Dec. 1377", "Protección estricta de datos personales y sensibilidad de historiales médicos."),
    ("Ley 23 de 1981 (Ética Médica)", "La app es herramienta de apoyo informativo; no prescribe de forma autónoma."),
    ("Ley 527 de 1999", "Validez jurídica a mensajes de datos y soporte para recetas electrónicas."),
    ("Ley 1438 de 2011", "Modernización e innovación tecnológica orientada a la atención primaria en salud."),
    ("Art. 49 Constitución Política", "Garantía del derecho fundamental a la salud y acceso a tratamientos.")
]
for t, d in law_items:
    p = rtf2.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 6: METODOLOGÍA KANBAN Y CRONOGRAMA
# =============================================================
s6 = prs.slides[5]
setup_header(s6, "5. Metodología Ágil y Cronograma", "Kanban como Eje Metodológico y Control de Actividades")

add_card(s6, Inches(0.8), Inches(1.9), Inches(5.6), Inches(4.75))
if os.path.exists(IMG_KANBAN):
    s6.shapes.add_picture(IMG_KANBAN, Inches(1.0), Inches(2.1), Inches(5.2), Inches(2.8))

ktf = s6.shapes.add_textbox(Inches(1.0), Inches(5.05), Inches(5.2), Inches(1.5)).text_frame
ktf.word_wrap = True
kp1 = ktf.paragraphs[0]
kp1.text = "📋 Principios Kanban Aplicados (Doc Pág. 16)"
kp1.font.size = Pt(14)
kp1.font.bold = True
kp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
kp1.space_after = Pt(4)

kp2 = ktf.add_paragraph()
kp2.text = "• Visualización en 4 estados: Backlog, En Progreso, En Revisión / Pruebas y Finalizado.\n• Límite de Trabajo en Progreso (WIP) y ciclos de mejora constante."
kp2.font.size = Pt(11.5)
kp2.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s6, Inches(6.7), Inches(1.9), Inches(5.8), Inches(4.75), bg_color=COLOR_UDEC_GREEN_LIGHT, border_color=COLOR_UDEC_GREEN)
ctf = s6.shapes.add_textbox(Inches(6.9), Inches(2.1), Inches(5.4), Inches(4.3)).text_frame
ctf.word_wrap = True

cp1 = ctf.paragraphs[0]
cp1.text = "📊 Estado del Cronograma 2026-2 (Pág. 19)"
cp1.font.size = Pt(16)
cp1.font.bold = True
cp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
cp1.space_after = Pt(10)

cron_stats = [
    ("Finalizado (Implementado y verificado)", "9 actividades (64.3%)"),
    ("En Curso (En ejecución activa)", "2 actividades (14.3%)"),
    ("Pendiente (Programado en cronograma)", "3 actividades (21.4%)"),
    ("Total de Actividades de Ingeniería", "14 actividades estructuradas")
]
for label, val in cron_stats:
    p = ctf.add_paragraph()
    p.text = f"✔ {label}: "
    p.font.bold = True
    p.font.size = Pt(12.5)
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = val
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

cp2 = ctf.add_paragraph()
cp2.text = "Avance Técnico Clave: Alarmas nativas, OCR de recetas, tema oscuro, modo cuidador y animales, y widgets ya cerrados y probados."
cp2.font.size = Pt(11.5)
cp2.font.color.rgb = COLOR_TEXT_MUTED
cp2.space_before = Pt(8)

# =============================================================
# SLIDE 7: CLEAN ARCHITECTURE Y STACK TECNOLÓGICO
# =============================================================
s7 = prs.slides[6]
setup_header(s7, "6. Arquitectura y Stack Tecnológico", "Clean Architecture Desacoplada y Servicios de Borde")

add_card(s7, Inches(0.8), Inches(1.9), Inches(5.6), Inches(4.75))
atf1 = s7.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(5.2), Inches(4.3)).text_frame
atf1.word_wrap = True

ap1 = atf1.paragraphs[0]
ap1.text = "🏛️ Patrón Clean Architecture"
ap1.font.size = Pt(16)
ap1.font.bold = True
ap1.font.color.rgb = COLOR_UDEC_GREEN_DARK
ap1.space_after = Pt(8)

arch_pts = [
    ("Separación Estricta de Capas", "Core, Models, Repositories, Use Cases, Services, Notifiers y Screens."),
    ("Manejo de Errores con Result", "Patrón Result para captura robusta de excepciones sin caídas en la UI."),
    ("Gestión de Estado Reactiva", "Implementado con Provider para desacoplar vistas y controladores."),
    ("Offline-First Caché", "Persistencia local que garantiza consultar tratamientos y registrar dosis sin internet.")
]
for t, d in arch_pts:
    p = atf1.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s7, Inches(6.7), Inches(1.9), Inches(5.8), Inches(4.75))
atf2 = s7.shapes.add_textbox(Inches(6.9), Inches(2.1), Inches(5.4), Inches(4.3)).text_frame
atf2.word_wrap = True

ap2 = atf2.paragraphs[0]
ap2.text = "🛠️ Stack Tecnológico Oficial (v2.37.0)"
ap2.font.size = Pt(16)
ap2.font.bold = True
ap2.font.color.rgb = COLOR_UDEC_GREEN_DARK
ap2.space_after = Pt(8)

stack_items = [
    ("Framework y Lenguaje", "Flutter 3.x y Dart 3.7 compilados de forma nativa."),
    ("Backend & Cloud", "Firebase Auth (OAuth Google/Correo) + Cloud Firestore NoSQL."),
    ("Inteligencia Artificial", "Groq LPU (Qwen 2.5-VL / Qwen 3.8-27b, LLaMA) + OpenAI Whisper."),
    ("Servicios Nativos Android", "android_alarm_manager_plus (AlarmRingingPage) y home_widget."),
    ("Georreferenciación & PDF", "MapLibre GL, Geolocator y motor de reportes con fl_chart.")
]
for t, d in stack_items:
    p = atf2.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 8: ECOSISTEMA MEDITIME (Móvil + Web GitHub)
# =============================================================
s8 = prs.slides[7]
setup_header(s8, "7. Ecosistema MediTime", "Aplicación Móvil Integral y Plataforma Web Oficial")

add_card(s8, Inches(0.8), Inches(1.9), Inches(5.6), Inches(4.75))
mtf = s8.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(5.2), Inches(4.3)).text_frame
mtf.word_wrap = True

mp1 = mtf.paragraphs[0]
mp1.text = "📱 Aplicación Móvil (v2.37.0)"
mp1.font.size = Pt(16)
mp1.font.bold = True
mp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
mp1.space_after = Pt(8)

app_feats = [
    ("Visión Artificial (OCR)", "Escaneo y extracción automática de recetas impresas o manuscritas."),
    ("Alarmas Nativas Críticas", "Pantalla completa (AlarmRingingPage) que enciende el móvil en Doze Mode."),
    ("Asistente Virtual Midi AI", "Chatbot con reconocimiento de voz (Whisper) y síntesis de habla."),
    ("Multiperfil Inclusivo", "Modo Cuidador para pacientes dependientes y Modo Animales (veterinaria)."),
    ("Informes Clínicos en PDF", "Exportación de métricas de adherencia y gráficas para el médico tratante.")
]
for t, d in app_feats:
    p = mtf.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s8, Inches(6.7), Inches(1.9), Inches(5.8), Inches(4.75), bg_color=COLOR_ACCENT_BG, border_color=COLOR_ACCENT_BORDER)
wtf = s8.shapes.add_textbox(Inches(6.9), Inches(2.1), Inches(5.4), Inches(4.3)).text_frame
wtf.word_wrap = True

wp1 = wtf.paragraphs[0]
wp1.text = "🌐 Plataforma Web Oficial (Anexos Pág. 22)"
wp1.font.size = Pt(16)
wp1.font.bold = True
wp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
wp1.space_after = Pt(8)

web_feats = [
    ("Portal de Difusión Abierto", "Sitio web para presentar el proyecto, características y arquitectura a la comunidad."),
    ("Descarga Directa de APK", "Conectado a GitHub Releases (releases/latest) para instalación inmediata sin intermediarios."),
    ("Transparencia y Open Source", "Repositorio público con control de versiones y trazabilidad de código."),
    ("Visor de Documentación", "Acceso público al manual de usuario, manual técnico y plan de sostenibilidad.")
]
for t, d in web_feats:
    p = wtf.add_paragraph()
    p.text = f"✔ {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 9: DEMOSTRACIÓN EN VIVO (LIVE DEMO)
# =============================================================
s9 = prs.slides[8]
setup_header(s9, "8. Demostración en Vivo", "Recorrido Funcional en Tiempo Real de la Plataforma Web y App")

add_card(s9, Inches(1.0), Inches(1.9), Inches(11.3), Inches(4.75))
dtf = s9.shapes.add_textbox(Inches(1.3), Inches(2.2), Inches(10.7), Inches(4.2)).text_frame
dtf.word_wrap = True

dp1 = dtf.paragraphs[0]
dp1.text = "🚀 Recorrido Demostrativo del Ecosistema MediTime:"
dp1.font.size = Pt(17)
dp1.font.bold = True
dp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
dp1.space_after = Pt(14)

demo_steps = [
    ("1. Portal Web y Descarga Directa", "Visualización del sitio web oficial y enlace de descarga del APK Release en GitHub Releases."),
    ("2. Digitalización de Receta y Creación", "Escaneo asistido por IA o registro de tratamiento con cálculo automático de horarios."),
    ("3. Ejecución de Alarma Nativa", "Disparo interactivo a pantalla completa (AlarmRingingPage) con confirmación de dosis tomada."),
    ("4. Interacción con Asistente Midi AI", "Pregunta médica por voz o chat procesada en tiempo real mediante Groq LPU."),
    ("5. Supervisión y Reporte Clínico", "Vista en Modo Cuidador y generación del informe médico en formato PDF.")
]
for s_num, s_desc in demo_steps:
    p = dtf.add_paragraph()
    p.text = f"• {s_num}: "
    p.font.bold = True
    p.font.size = Pt(13.5)
    p.font.color.rgb = COLOR_UDEC_GREEN
    p.space_after = Pt(8)
    r = p.add_run()
    r.text = s_desc
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 10: ALCANCES Y DESAFÍOS DE DESPLIEGUE
# =============================================================
s10 = prs.slides[9]
setup_header(s10, "9. Alcances y Desafíos de Despliegue", "Alcances Consolidados y Ruta Técnica hacia la Transferencia")

add_card(s10, Inches(0.8), Inches(1.9), Inches(5.6), Inches(4.75))
ltf1 = s10.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(5.2), Inches(4.3)).text_frame
ltf1.word_wrap = True

lp1 = ltf1.paragraphs[0]
lp1.text = "✅ Alcances Consolidados (Doc Pág. 8)"
lp1.font.size = Pt(15.5)
lp1.font.bold = True
lp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
lp1.space_after = Pt(8)

alcances = [
    ("Digitalización Multimodal", "Visión artificial (Qwen Vision) y asistencia por voz (Whisper)."),
    ("Soberanía Offline", "Persistencia local para tomas y consultas en zonas sin cobertura."),
    ("Supervisión Multiperfil", "Módulos activos de Cuidador (dependientes) y Animales (veterinaria)."),
    ("Integración al Sistema Operativo", "Widgets de escritorio en Android y geolocalización de droguerías."),
    ("Control de Stock", "Deducción automática de dosis en inventario con alerta de reposición.")
]
for t, d in alcances:
    p = ltf1.add_paragraph()
    p.text = f"• {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

add_card(s10, Inches(6.7), Inches(1.9), Inches(5.8), Inches(4.75))
ltf2 = s10.shapes.add_textbox(Inches(6.9), Inches(2.1), Inches(5.4), Inches(4.3)).text_frame
ltf2.word_wrap = True

lp2 = ltf2.paragraphs[0]
lp2.text = "📌 Desafíos de Despliegue (Doc Pág. 18)"
lp2.font.size = Pt(15.5)
lp2.font.bold = True
lp2.font.color.rgb = COLOR_UDEC_GREEN_DARK
lp2.space_after = Pt(8)

desafios = [
    ("Publicación en Google Play Store", "Tránsito de certificación cumpliendo directivas de privacidad y seguridad en datos de salud."),
    ("Pruebas de Usabilidad Territorial", "Ejecución de pruebas de campo con adultos mayores y cuidadores en municipios de Cundinamarca."),
    ("Monitoreo de Consumo Cloud", "Supervisión de cuotas de tokens en microservicios Groq y Firebase bajo uso simultáneo."),
    ("Interoperabilidad Práctica", "Uso de informes PDF estandarizados para salvar la brecha de integración con sistemas EPS/IPS.")
]
for t, d in desafios:
    p = ltf2.add_paragraph()
    p.text = f"➔ {t}: "
    p.font.bold = True
    p.font.size = Pt(12)
    p.font.color.rgb = COLOR_UDEC_GREEN_DARK
    p.space_after = Pt(6)
    r = p.add_run()
    r.text = d
    r.font.bold = False
    r.font.color.rgb = COLOR_TEXT_PRIMARY

# =============================================================
# SLIDE 11: MINUTO EN INGLÉS (Abstract del Proyecto)
# =============================================================
s11 = prs.slides[10]
setup_header(s11, "10. Minuto en Inglés (English Minute)", "Official Project Abstract and Research Significance (60-Second Speech)")

badges_en = [
    ("~50% Non-Adherence", "Clinical Problem (WHO)"),
    ("Multimodal Edge AI", "Qwen Vision & Whisper"),
    ("100% Native Alarms", "Doze Mode Bypass"),
    ("Caregiver & Web", "Social Accessibility")
]
for idx, (b_title, b_sub) in enumerate(badges_en):
    left = Inches(0.8 + idx * 2.95)
    shape = s11.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(1.85), Inches(2.8), Inches(0.95))
    shape.fill.solid()
    shape.fill.fore_color.rgb = COLOR_UDEC_GREEN_LIGHT
    shape.line.color.rgb = COLOR_UDEC_GREEN
    shape.line.width = Pt(1.3)
    tf_b = shape.text_frame
    tf_b.word_wrap = True
    tf_b.vertical_anchor = MSO_ANCHOR.MIDDLE
    bp1 = tf_b.paragraphs[0]
    bp1.text = b_title
    bp1.font.size = Pt(12.5)
    bp1.font.bold = True
    bp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
    bp1.alignment = PP_ALIGN.CENTER
    bp2 = tf_b.add_paragraph()
    bp2.text = b_sub
    bp2.font.size = Pt(10)
    bp2.font.color.rgb = COLOR_TEXT_MUTED
    bp2.alignment = PP_ALIGN.CENTER

add_card(s11, Inches(0.8), Inches(3.0), Inches(11.7), Inches(3.65), bg_color=COLOR_ACCENT_BG, border_color=COLOR_ACCENT_BORDER)
stf11 = s11.shapes.add_textbox(Inches(1.1), Inches(3.15), Inches(11.1), Inches(3.35)).text_frame
stf11.word_wrap = True

sp11 = stf11.paragraphs[0]
sp11.text = '"Distinguished members of the evaluation committee:'
sp11.font.size = Pt(13)
sp11.font.bold = True
sp11.font.color.rgb = COLOR_UDEC_GREEN_DARK
sp11.space_after = Pt(6)

lines_thesis_en = [
    "This project consolidates MediTime (v2.37.0), a comprehensive mobile solution designed to maximize compliance and accuracy in medical prescription management by leveraging emerging technologies.",
    "Built on Flutter and supported by Google Firebase and Groq LPU, the application surpasses conventional apps by integrating vision-based OCR extraction of handwritten prescriptions and conversational assistance via Midi AI.",
    "Furthermore, high-priority full-screen native alarms reliably bypass Android Doze Mode, while Caregiver and Pets modes expand social supervision for dependent family members.",
    "Finally, supported by our open-source web platform connected to GitHub Releases, MediTime ensures direct access, patient autonomy, and medication safety.\nThank you very much.\""
]
for l in lines_thesis_en:
    p = stf11.add_paragraph()
    p.text = l
    p.font.size = Pt(11.8)
    p.font.color.rgb = COLOR_TEXT_PRIMARY
    p.space_after = Pt(4)

# =============================================================
# SLIDE 12: CONCLUSIONES DE INGENIERÍA (¡Diapositiva Propia Aparte!)
# =============================================================
s12 = prs.slides[11]
setup_header(s12, "11. Conclusiones de Ingeniería", "Balance Técnico y Resultados del Proyecto (Doc Pág. 19-20)")

# 4 Dedicated Cards for Conclusions
concs = [
    ("Visión Artificial y PLN en Registro", "La integración de modelos de visión por computadora y procesamiento de lenguaje natural demostró reducir drásticamente la fricción y los errores de digitación en el registro de medicamentos, transformando un proceso tradicionalmente tedioso en una captura asistida e intuitiva."),
    ("Fiabilidad en Motor de Alarmas Nativo", "La implementación de notificaciones a pantalla completa (AlarmRingingPage), respaldada por administradores de tareas nativas de Android, solucionó de forma definitiva la omisión de recordatorios por restricciones del sistema operativo (Doze Mode)."),
    ("Impacto Social con Modo Cuidador y Animales", "La inclusión de supervisión multiperfil amplió el alcance de MediTime, transformándola de una simple herramienta de autocuidado individual a un centro de supervisión clínica colaborativa para hogares con personas mayores, pacientes dependientes y mascotas."),
    ("Soberanía de Datos y Operación Offline", "La arquitectura híbrida (Cloud Firestore + Almacenamiento local en SQLite + Exportación en PDF) probó que es posible garantizar soberanía y operatividad en zonas de baja conectividad, cerrando la brecha con el personal de salud mediante informes estandarizados.")
]

for idx, (c_title, c_desc) in enumerate(concs):
    row = idx // 2
    col = idx % 2
    left = Inches(0.8 + col * 5.9)
    top = Inches(1.9 + row * 2.45)
    
    card = add_card(s12, left, top, Inches(5.7), Inches(2.3))
    
    tbox = s12.shapes.add_textbox(left + Inches(0.2), top + Inches(0.18), Inches(5.3), Inches(1.95))
    ctf12 = tbox.text_frame
    ctf12.word_wrap = True
    
    cp1 = ctf12.paragraphs[0]
    cp1.text = f"{idx+1}. {c_title}"
    cp1.font.size = Pt(13.5)
    cp1.font.bold = True
    cp1.font.color.rgb = COLOR_UDEC_GREEN_DARK
    cp1.space_after = Pt(6)
    
    cp2 = ctf12.add_paragraph()
    cp2.text = c_desc
    cp2.font.size = Pt(11.2)
    cp2.font.color.rgb = COLOR_TEXT_PRIMARY
    cp2.line_spacing = 1.15

# =============================================================
# SLIDE 13: CIERRE INSTITUCIONAL (¡MUCHAS GRACIAS Y PREGUNTAS!)
# =============================================================
s13 = prs.slides[12]
for shape in list(s13.shapes):
    if shape.has_text_frame:
        sp = shape._element
        sp.getparent().remove(sp)

t_box = s13.shapes.add_textbox(Inches(1.0), Inches(1.5), Inches(11.3), Inches(0.85))
ttf13 = t_box.text_frame
ttf13.word_wrap = True
tp13 = ttf13.paragraphs[0]
tp13.text = "¡Transformemos la salud en Colombia!"
tp13.font.size = Pt(36)
tp13.font.bold = True
tp13.font.color.rgb = COLOR_TEXT_WHITE
tp13.alignment = PP_ALIGN.CENTER

sub_box = s13.shapes.add_textbox(Inches(1.0), Inches(2.4), Inches(11.3), Inches(1.7))
stf13 = sub_box.text_frame
stf13.word_wrap = True

sp1 = stf13.paragraphs[0]
sp1.text = "¡Muchas Gracias por su Atención!"
sp1.font.size = Pt(20)
sp1.font.bold = True
sp1.font.color.rgb = RGBColor(187, 247, 208)
sp1.alignment = PP_ALIGN.CENTER
sp1.space_after = Pt(6)

sp2 = stf13.add_paragraph()
sp2.text = "Espacio para Sustentación y Preguntas del Jurado Evaluador"
sp2.font.size = Pt(14)
sp2.font.bold = True
sp2.font.color.rgb = COLOR_TEXT_WHITE
sp2.alignment = PP_ALIGN.CENTER
sp2.space_after = Pt(8)

sp3 = stf13.add_paragraph()
sp3.text = "Johan Alexander Arévalo Contreras & Jorge Eliecer Delgado Cortés\nPrograma de Ingeniería de Sistemas • Universidad de Cundinamarca — Seccional Ubaté (2026-2)"
sp3.font.size = Pt(11.5)
sp3.font.color.rgb = RGBColor(209, 213, 219)
sp3.alignment = PP_ALIGN.CENTER

# QR Code
if os.path.exists(IMG_QR):
    s13.shapes.add_picture(IMG_QR, Inches(3.2), Inches(4.35), Inches(2.2), Inches(2.2))

qr_desc = s13.shapes.add_textbox(Inches(5.7), Inches(4.4), Inches(5.5), Inches(2.1))
qtf = qr_desc.text_frame
qtf.word_wrap = True

qp1 = qtf.paragraphs[0]
qp1.text = "Anexos Oficiales del Proyecto (Doc Pág. 22):"
qp1.font.size = Pt(13.5)
qp1.font.bold = True
qp1.font.color.rgb = RGBColor(254, 240, 138)
qp1.space_after = Pt(6)

qp2 = qtf.add_paragraph()
qp2.text = "📄 Manual de Usuario & Manual Técnico\n💡 Plan de Sostenibilidad Operativa\n🌐 Sitio Web Oficial & Repositorio GitHub\n📦 Enlace de Descarga APK Release (releases/latest)"
qp2.font.size = Pt(11)
qp2.font.color.rgb = COLOR_TEXT_WHITE
qp2.space_after = Pt(6)

qp3 = qtf.add_paragraph()
qp3.text = "github.com/JDkinior/MediTime"
qp3.font.size = Pt(11.5)
qp3.font.bold = True
qp3.font.color.rgb = RGBColor(187, 247, 208)

# Save presentation
prs.save(OUT_PPTX)
print("Saved PPTX to:", OUT_PPTX)

# Convert to PDF
print("Converting to PDF via PowerPoint COM...")
ppt_app = win32com.client.Dispatch('PowerPoint.Application')
pres = ppt_app.Presentations.Open(os.path.abspath(OUT_PPTX), WithWindow=False)
pres.SaveAs(os.path.abspath(OUT_PDF), 32)

# Export PNG previews
out_dir = os.path.abspath(r'C:\Users\degkp\Documents\Proyectos\MediTime\documentos\slides_preview')
for i in range(1, pres.Slides.Count + 1):
    slide = pres.Slides(i)
    png_path = os.path.join(out_dir, f'slide_{i:02d}.png')
    slide.Export(png_path, 'PNG', 1920, 1080)

pres.Close()
ppt_app.Quit()

print("PDF exported successfully to:", OUT_PDF)
print("Deck with separate conclusions finished successfully!")
