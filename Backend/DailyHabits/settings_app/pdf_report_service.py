"""
PDF Report Service — settings_app/pdf_report_service.py
========================================================

Generates a professional, multi-section habit analytics report using
ReportLab.  The report is built entirely in-memory (no temp files) and
returned as raw ``bytes`` ready to be streamed in an ``HttpResponse``.

Report Sections:
    1. Title / Header — app name, report title, generated date.
    2. User Information — name, email.
    3. Habit Summary — total habits, completed, completion rate.
    4. Streak Overview — best streak, current streak, avg consistency.
    5. Category Breakdown — table of categories with habit counts & rates.
    6. Habit Detail Table — per-habit streaks, consistency, success rate.
    7. Weekly Progress — day-by-day completion data for the current week.
    8. Footer — page numbers & generation timestamp.

Design decisions:
    • Uses ``SimpleDocTemplate`` with custom ``PageTemplate`` for header/footer.
    • Colour palette mirrors the DailyHabits brand (indigo primary, grey text).
    • All data is fetched from ``AnalyticsService`` to stay DRY.
    • Font sizes and spacing are tuned for A4 output and screen readability.
"""

import io
from datetime import datetime

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch, mm
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    HRFlowable,
    PageBreak,
)

from analytics.services import AnalyticsService
from habits.models import Habit, HabitLog


# =========================================================================
#  COLOUR PALETTE — mirrors DailyHabits brand tokens
# =========================================================================

_PRIMARY = colors.HexColor('#4F46E5')       # Indigo-600
_PRIMARY_LIGHT = colors.HexColor('#E0E7FF') # Indigo-50
_SUCCESS = colors.HexColor('#059669')       # Emerald-600
_WARNING = colors.HexColor('#D97706')       # Amber-600
_DANGER = colors.HexColor('#DC2626')        # Red-600
_TEXT_DARK = colors.HexColor('#1E293B')     # Slate-800
_TEXT_MED = colors.HexColor('#475569')      # Slate-600
_TEXT_LIGHT = colors.HexColor('#94A3B8')    # Slate-400
_BG_LIGHT = colors.HexColor('#F8FAFC')     # Slate-50
_BORDER = colors.HexColor('#E2E8F0')       # Slate-200


# =========================================================================
#  CUSTOM STYLES
# =========================================================================

def _custom_styles():
    """
    Build a dict of ``ParagraphStyle`` objects used throughout the report.

    Returns:
        dict[str, ParagraphStyle]: Keyed by logical name (title, heading, etc.)
    """
    base = getSampleStyleSheet()
    return {
        'title': ParagraphStyle(
            'ReportTitle',
            parent=base['Title'],
            fontSize=24,
            textColor=_PRIMARY,
            spaceAfter=4,
            fontName='Helvetica-Bold',
        ),
        'subtitle': ParagraphStyle(
            'ReportSubtitle',
            parent=base['Normal'],
            fontSize=11,
            textColor=_TEXT_MED,
            spaceAfter=16,
        ),
        'heading': ParagraphStyle(
            'SectionHeading',
            parent=base['Heading2'],
            fontSize=14,
            textColor=_PRIMARY,
            spaceBefore=18,
            spaceAfter=8,
            fontName='Helvetica-Bold',
        ),
        'body': ParagraphStyle(
            'BodyText',
            parent=base['Normal'],
            fontSize=10,
            textColor=_TEXT_DARK,
            leading=14,
        ),
        'body_bold': ParagraphStyle(
            'BodyBold',
            parent=base['Normal'],
            fontSize=10,
            textColor=_TEXT_DARK,
            fontName='Helvetica-Bold',
            leading=14,
        ),
        'label': ParagraphStyle(
            'Label',
            parent=base['Normal'],
            fontSize=9,
            textColor=_TEXT_MED,
        ),
        'value': ParagraphStyle(
            'Value',
            parent=base['Normal'],
            fontSize=12,
            textColor=_TEXT_DARK,
            fontName='Helvetica-Bold',
        ),
        'footer': ParagraphStyle(
            'Footer',
            parent=base['Normal'],
            fontSize=8,
            textColor=_TEXT_LIGHT,
            alignment=TA_CENTER,
        ),
    }


# =========================================================================
#  HELPER: metric box (label + value pair)
# =========================================================================

def _metric_cell(label: str, value: str, styles: dict) -> list:
    """
    Create a two-paragraph metric element (label on top, bold value below).

    Args:
        label:  Small grey descriptor text.
        value:  Large bold primary value text.
        styles: The custom styles dict.

    Returns:
        list: Two ``Paragraph`` objects suitable for a Table cell.
    """
    return [
        Paragraph(label, styles['label']),
        Paragraph(str(value), styles['value']),
    ]


# =========================================================================
#  STANDARD TABLE STYLE
# =========================================================================

_TABLE_STYLE = TableStyle([
    # Header row
    ('BACKGROUND', (0, 0), (-1, 0), _PRIMARY),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
    ('FONTSIZE', (0, 0), (-1, 0), 9),
    ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
    ('TOPPADDING', (0, 0), (-1, 0), 8),

    # Data rows
    ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
    ('FONTSIZE', (0, 1), (-1, -1), 9),
    ('TOPPADDING', (0, 1), (-1, -1), 6),
    ('BOTTOMPADDING', (0, 1), (-1, -1), 6),

    # Alternating row shading
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, _BG_LIGHT]),

    # Borders
    ('LINEBELOW', (0, 0), (-1, 0), 1, _PRIMARY),
    ('LINEBELOW', (0, 1), (-1, -2), 0.5, _BORDER),
    ('LINEBELOW', (0, -1), (-1, -1), 1, _BORDER),

    # Alignment
    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
])


# =========================================================================
#  MAIN ENTRY POINT
# =========================================================================

def generate_habit_report_pdf(user) -> bytes:
    """
    Generate a complete Habit Analytics Report PDF for the given user.

    Collects analytics data via ``AnalyticsService``, builds the ReportLab
    document in-memory, and returns raw PDF bytes.

    Args:
        user: An authenticated Django ``User`` instance.

    Returns:
        bytes: The rendered PDF document.

    Raises:
        Exception: Propagated from AnalyticsService or ReportLab if data
                   collection or rendering fails.
    """
    buffer = io.BytesIO()
    styles = _custom_styles()
    now = timezone.now()

    # ── Collect all analytics data ────────────────────────────────────
    dashboard = AnalyticsService.get_dashboard_summary(user)
    habit_stats = AnalyticsService.get_habit_stats(user)
    categories = AnalyticsService.get_category_breakdown(user)
    weekly_data = AnalyticsService.get_weekly_data(user)

    # Total habit counts
    total_habits = Habit.objects.filter(
        user=user, status='active', is_deleted=False).count()
    today = now.date()
    today_completed = HabitLog.objects.filter(
        habit__user=user,
        habit__status='active',
        habit__is_deleted=False,
        date=today,
        status='completed',
    ).count()
    completion_rate = round(
        (today_completed / total_habits * 100) if total_habits > 0 else 0, 1,
    )

    # ── Build the document ────────────────────────────────────────────
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        topMargin=20 * mm,
        bottomMargin=20 * mm,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        title='DailyHabits — Habit Analytics Report',
        author=user.name or user.email,
    )

    story = []

    # ==================================================================
    # 1. HEADER
    # ==================================================================
    story.append(Paragraph('DailyHabits', styles['title']))
    story.append(Paragraph('Habit Analytics Report', ParagraphStyle(
        'ReportHeading',
        parent=styles['body'],
        fontSize=16,
        textColor=_TEXT_DARK,
        fontName='Helvetica-Bold',
        spaceAfter=4,
    )))
    story.append(Paragraph(
        f'Generated on {now.strftime("%B %d, %Y at %I:%M %p")}',
        styles['subtitle'],
    ))
    story.append(HRFlowable(
        width='100%', thickness=2, color=_PRIMARY, spaceAfter=12,
    ))

    # ==================================================================
    # 2. USER INFORMATION
    # ==================================================================
    story.append(Paragraph('User Information', styles['heading']))
    user_data = [
        ['Name', user.name or '—'],
        ['Email', user.email],
    ]
    user_table = Table(user_data, colWidths=[120, 350])
    user_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('TEXTCOLOR', (0, 0), (0, -1), _TEXT_MED),
        ('TEXTCOLOR', (1, 0), (1, -1), _TEXT_DARK),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LINEBELOW', (0, 0), (-1, -1), 0.5, _BORDER),
    ]))
    story.append(user_table)
    story.append(Spacer(1, 8))

    # ==================================================================
    # 3. HABIT SUMMARY
    # ==================================================================
    story.append(Paragraph('Habit Summary', styles['heading']))

    summary_data = [[
        Paragraph('Total Habits', styles['label']),
        Paragraph('Completed Today', styles['label']),
        Paragraph('Completion Rate', styles['label']),
        Paragraph('Best Streak', styles['label']),
    ], [
        Paragraph(str(total_habits), styles['value']),
        Paragraph(str(today_completed), styles['value']),
        Paragraph(f'{completion_rate}%', styles['value']),
        Paragraph(f'{dashboard.get("bestStreak", 0)} days', styles['value']),
    ]]
    summary_table = Table(summary_data, colWidths=[120, 120, 120, 120])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), _BG_LIGHT),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('ROUNDEDCORNERS', [6, 6, 6, 6]),
        ('BOX', (0, 0), (-1, -1), 1, _BORDER),
        ('LINEBEFORE', (1, 0), (1, -1), 0.5, _BORDER),
        ('LINEBEFORE', (2, 0), (2, -1), 0.5, _BORDER),
        ('LINEBEFORE', (3, 0), (3, -1), 0.5, _BORDER),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 8))

    # ==================================================================
    # 4. STREAK OVERVIEW
    # ==================================================================
    story.append(Paragraph('Streak Overview', styles['heading']))
    streak_data = [[
        Paragraph('Current Streak', styles['label']),
        Paragraph('Best Streak', styles['label']),
        Paragraph('Avg Consistency (30d)', styles['label']),
        Paragraph('Weekly Completions', styles['label']),
    ], [
        Paragraph(f'{dashboard.get("currentStreak", 0)} days', styles['value']),
        Paragraph(f'{dashboard.get("bestStreak", 0)} days', styles['value']),
        Paragraph(f'{dashboard.get("avgConsistency", 0)}%', styles['value']),
        Paragraph(str(dashboard.get('weeklyCompletions', 0)), styles['value']),
    ]]
    streak_table = Table(streak_data, colWidths=[120, 120, 120, 120])
    streak_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), _PRIMARY_LIGHT),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('BOX', (0, 0), (-1, -1), 1, _PRIMARY),
        ('LINEBEFORE', (1, 0), (1, -1), 0.5, _BORDER),
        ('LINEBEFORE', (2, 0), (2, -1), 0.5, _BORDER),
        ('LINEBEFORE', (3, 0), (3, -1), 0.5, _BORDER),
    ]))
    story.append(streak_table)
    story.append(Spacer(1, 8))

    # ==================================================================
    # 5. CATEGORY BREAKDOWN
    # ==================================================================
    if categories:
        story.append(Paragraph('Category Breakdown', styles['heading']))
        cat_header = ['Category', 'Habits', 'Avg Consistency', 'Status']
        cat_rows = [cat_header]
        for cat in categories:
            consistency = cat.get('avgConsistency', 0)
            status_text = (
                'Excellent' if consistency >= 80 else
                'Good' if consistency >= 60 else
                'Needs Work' if consistency >= 40 else
                'Low'
            )
            cat_rows.append([
                cat.get('category', '—'),
                str(cat.get('count', 0)),
                f'{consistency}%',
                status_text,
            ])
        cat_table = Table(cat_rows, colWidths=[150, 80, 120, 120])
        cat_table.setStyle(_TABLE_STYLE)
        story.append(cat_table)
        story.append(Spacer(1, 8))

    # ==================================================================
    # 6. HABIT DETAIL TABLE
    # ==================================================================
    if habit_stats:
        story.append(Paragraph('Habit Performance Details', styles['heading']))
        habit_header = [
            'Habit Name', 'Category', 'Current Streak',
            'Best Streak', 'Consistency (30d)', 'Success Rate',
        ]
        habit_rows = [habit_header]
        for h in habit_stats:
            habit_rows.append([
                h.get('title', '—'),
                h.get('category', '—'),
                f'{h.get("currentStreak", 0)} days',
                f'{h.get("bestStreak", 0)} days',
                f'{h.get("consistency30d", 0)}%',
                f'{h.get("successRate", 0)}%',
            ])
        habit_table = Table(habit_rows, colWidths=[110, 80, 75, 70, 85, 75])
        habit_table.setStyle(_TABLE_STYLE)
        story.append(habit_table)
        story.append(Spacer(1, 8))

    # ==================================================================
    # 7. WEEKLY PROGRESS
    # ==================================================================
    if weekly_data:
        story.append(Paragraph('This Week\'s Progress', styles['heading']))
        week_header = ['Day', 'Date', 'Completed', 'Total', 'Rate']
        week_rows = [week_header]
        for d in weekly_data:
            day_label = d.get('day', '')
            if d.get('isToday'):
                day_label += ' (Today)'
            week_rows.append([
                day_label,
                d.get('date', ''),
                str(d.get('completed', 0)),
                str(d.get('total', 0)),
                f'{d.get("rate", 0)}%',
            ])
        week_table = Table(week_rows, colWidths=[100, 100, 80, 80, 80])
        week_table.setStyle(_TABLE_STYLE)
        story.append(week_table)

    # ==================================================================
    # 8. FOOTER NOTE
    # ==================================================================
    story.append(Spacer(1, 24))
    story.append(HRFlowable(width='100%', thickness=1, color=_BORDER))
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        f'DailyHabits — Habit Analytics Report  •  '
        f'Generated {now.strftime("%Y-%m-%d %H:%M")}  •  '
        f'For {user.email}',
        styles['footer'],
    ))

    # ── Render to bytes ───────────────────────────────────────────────
    doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()
    return pdf_bytes
