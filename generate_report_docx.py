"""
INTERA Summer Training Report Generator
========================================
Generates a .docx file matching the Amritsar Group of Colleges
Summer Training Report format guidelines exactly.

Section Order:
  Title Page (not numbered)
  Table of Contents
  Summer Training Certificate  (i)
  Declaration                  (ii)
  Acknowledgement              (iii)
  List of Figures               (iv)
  List of Tables                (v)
  Training Objective            (1)
  Organization Brief            (2)
  Technology Used               (3)
  Software Model                (4)
  Project Details               (5)
  Project Screenshots           (6)
  Bibliography

Formatting:
  Font: Times New Roman throughout
  Main Heading: 14pt Bold, Centered
  Sub-heading: 12pt Bold
  Body text: 12pt, Justified, 1.5 line spacing
  Margins: 1 inch all sides
  Tables/Figures: 10pt, centered, captions below in 10pt regular centered
  Page numbers: Roman (prelim), Arabic (main), centered in footer
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor, Cm, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.enum.section import WD_ORIENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn, nsdecls

# ─── XML helpers ──────────────────────────────────────────────────────────────

def set_cell_shading(cell, hex_color):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=80, bottom=80, left=100, right=100):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)

def set_table_borders(table, color="000000", sz="4"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'<w:top w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:left w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:bottom w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:right w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideH w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideV w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def remove_table_borders(table):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'<w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        f'<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        f'<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        f'<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        f'<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        f'<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def add_page_number_to_footer(section, num_fmt="decimal"):
    """Adds a centered page number field to the section footer.
    num_fmt: 'decimal' for 1,2,3 or 'lowerRoman' for i,ii,iii
    """
    footer = section.footer
    footer.is_linked_to_previous = False
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER

    # PAGE field
    fldChar1 = OxmlElement('w:fldChar')
    fldChar1.set(qn('w:fldCharType'), 'begin')
    run1 = p.add_run()
    run1._r.append(fldChar1)

    instrText = OxmlElement('w:instrText')
    instrText.set(qn('xml:space'), 'preserve')
    instrText.text = ' PAGE '
    run2 = p.add_run()
    run2._r.append(instrText)

    fldChar2 = OxmlElement('w:fldChar')
    fldChar2.set(qn('w:fldCharType'), 'end')
    run3 = p.add_run()
    run3._r.append(fldChar2)

    for run in p.runs:
        run.font.name = 'Times New Roman'
        run.font.size = Pt(10)

    # Set page number format
    sectPr = section._sectPr
    pgNumType = sectPr.find(qn('w:pgNumType'))
    if pgNumType is None:
        pgNumType = OxmlElement('w:pgNumType')
        sectPr.append(pgNumType)
    pgNumType.set(qn('w:fmt'), num_fmt)

def set_page_start(section, start_num, num_fmt="decimal"):
    """Set starting page number and format for a section."""
    sectPr = section._sectPr
    pgNumType = sectPr.find(qn('w:pgNumType'))
    if pgNumType is None:
        pgNumType = OxmlElement('w:pgNumType')
        sectPr.append(pgNumType)
    pgNumType.set(qn('w:fmt'), num_fmt)
    pgNumType.set(qn('w:start'), str(start_num))


# ─── Document Builder ─────────────────────────────────────────────────────────

def build_report():
    doc = Document()

    # ── Global styles ─────────────────────────────────────────────────────────
    style = doc.styles['Normal']
    style.font.name = 'Times New Roman'
    style.font.size = Pt(12)
    style.font.color.rgb = RGBColor(0, 0, 0)
    style.paragraph_format.line_spacing = 1.5
    style.paragraph_format.space_after = Pt(6)

    # Set margins for all existing sections (1 inch = 2.54 cm)
    for section in doc.sections:
        section.top_margin = Inches(1)
        section.bottom_margin = Inches(1)
        section.left_margin = Inches(1)
        section.right_margin = Inches(1)

    # ── Helper functions ──────────────────────────────────────────────────────

    def _run(para, text, size=12, bold=False, italic=False, color=None, underline=False):
        """Add a formatted run to a paragraph."""
        r = para.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(size)
        r.font.bold = bold
        r.font.italic = italic
        r.font.underline = underline
        if color:
            r.font.color.rgb = RGBColor(*color)
        return r

    def centered_text(text, size=12, bold=False, space_before=0, space_after=6, italic=False, underline=False):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(space_before)
        p.paragraph_format.space_after = Pt(space_after)
        p.paragraph_format.line_spacing = 1.5
        _run(p, text, size=size, bold=bold, italic=italic, underline=underline)
        return p

    def heading_main(text, space_before=12, space_after=12):
        """Main heading: 14pt Bold, Centered."""
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(space_before)
        p.paragraph_format.space_after = Pt(space_after)
        p.paragraph_format.line_spacing = 1.5
        _run(p, text.upper(), size=14, bold=True)
        return p

    def heading_sub(text, space_before=10, space_after=6):
        """Sub-heading: 12pt Bold, Left."""
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.space_before = Pt(space_before)
        p.paragraph_format.space_after = Pt(space_after)
        p.paragraph_format.line_spacing = 1.5
        _run(p, text, size=12, bold=True)
        return p

    def body(text, space_after=6, align=WD_ALIGN_PARAGRAPH.JUSTIFY):
        """Body text: 12pt, Justified, 1.5 spacing."""
        p = doc.add_paragraph()
        p.alignment = align
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_after = Pt(space_after)
        _run(p, text, size=12)
        return p

    def bullet(text, bold_label=""):
        """Bullet point with optional bold prefix label."""
        p = doc.add_paragraph(style='List Bullet')
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_after = Pt(4)
        if bold_label:
            _run(p, bold_label, size=12, bold=True)
        _run(p, text, size=12)
        return p

    def spacer(pts=12):
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(pts)
        p.paragraph_format.space_before = Pt(0)
        return p

    def add_new_section():
        """Add a new section (page break) with 1-inch margins."""
        doc.add_section()
        new_section = doc.sections[-1]
        new_section.top_margin = Inches(1)
        new_section.bottom_margin = Inches(1)
        new_section.left_margin = Inches(1)
        new_section.right_margin = Inches(1)
        return new_section

    def code_block(title, code):
        """Formatted code block inside a shaded table cell."""
        p_title = doc.add_paragraph()
        p_title.paragraph_format.space_before = Pt(8)
        p_title.paragraph_format.space_after = Pt(2)
        _run(p_title, f"Source File: {title}", size=10, bold=True, italic=True)

        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = table.cell(0, 0)
        set_cell_shading(cell, "F4F5F7")
        set_cell_margins(cell, top=100, bottom=100, left=120, right=120)

        p = cell.paragraphs[0]
        p.paragraph_format.line_spacing = 1.0
        p.paragraph_format.space_after = Pt(0)

        lines = code.strip().split('\n')
        for i, line in enumerate(lines):
            r = p.add_run(line + ('\n' if i < len(lines) - 1 else ''))
            r.font.name = 'Consolas'
            r.font.size = Pt(9)
            r.font.color.rgb = RGBColor(30, 30, 30)

        spacer(4)

    def figure_caption(text):
        """Figure caption: 10pt, Regular, Centered."""
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(10)
        _run(p, text, size=10)

    # ═══════════════════════════════════════════════════════════════════════════
    #  TITLE PAGE (Not numbered)
    # ═══════════════════════════════════════════════════════════════════════════

    # College name (matching the reference image exactly)
    centered_text("Amritsar Group of Colleges, Amritsar", size=18, bold=True, space_before=24, space_after=2)
    centered_text("Autonomous status conferred by UGC under UGC act-1956, (2f), NAAC-A Grade,", size=10, space_after=2, italic=True)
    centered_text("(Formerly Known as Amritsar College of Engineering & Technology | Amritsar Pharmacy College)", size=9, space_after=30, italic=True)

    # Report title
    centered_text("Summer Training Report", size=16, bold=True, space_after=4)
    centered_text("On", size=12, space_after=4, italic=True)
    spacer(6)
    centered_text("\u201CINTERA\u201D", size=20, bold=True, space_after=6)
    spacer(2)
    centered_text("Submitted in the partial fulfillment of the requirement for award of degree of", size=12, space_after=4)
    centered_text("Bachelor of Technology", size=14, bold=True, space_after=2)
    centered_text("In", size=12, space_after=2)
    centered_text("COMPUTER SCIENCE AND ENGINEERING", size=14, bold=True, space_after=2)
    centered_text("Batch (2024-2028)", size=12, space_after=24)

    # College logo placeholder
    logo_table = doc.add_table(rows=1, cols=1)
    logo_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    logo_cell = logo_table.cell(0, 0)
    logo_cell.width = Inches(2.0)
    set_cell_shading(logo_cell, "F5F5F5")
    set_cell_margins(logo_cell, top=200, bottom=200, left=200, right=200)
    lp = logo_cell.paragraphs[0]
    lp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    _run(lp, "[ COLLEGE LOGO ]", size=10, bold=True, color=(100, 100, 100))

    spacer(24)

    # Submitted to / Submitted by (matching reference image layout)
    sub_table = doc.add_table(rows=1, cols=2)
    sub_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    remove_table_borders(sub_table)
    cl = sub_table.cell(0, 0)
    cr = sub_table.cell(0, 1)
    cl.width = Inches(3.0)
    cr.width = Inches(3.0)

    pl = cl.paragraphs[0]
    pl.alignment = WD_ALIGN_PARAGRAPH.LEFT
    rl1 = pl.add_run("Submitted to:\n")
    rl1.font.name = 'Times New Roman'
    rl1.font.size = Pt(12)
    rl1.font.bold = True
    rl2 = pl.add_run("Department of CSE")
    rl2.font.name = 'Times New Roman'
    rl2.font.size = Pt(12)

    pr = cr.paragraphs[0]
    pr.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    rr1 = pr.add_run("Submitted by:\n")
    rr1.font.name = 'Times New Roman'
    rr1.font.size = Pt(12)
    rr1.font.bold = True
    rr2 = pr.add_run("Krish Sharma\n")
    rr2.font.name = 'Times New Roman'
    rr2.font.size = Pt(12)
    rr3 = pr.add_run("(Uni. Roll: 2411680)")
    rr3.font.name = 'Times New Roman'
    rr3.font.size = Pt(12)

    spacer(36)

    # Department line at bottom
    centered_text("DEPARTMENT OF COMPUTER SCIENCE & ENGINEERING", size=12, bold=True, space_after=0)

    # Title page: suppress page number
    title_section = doc.sections[0]
    title_section.footer.is_linked_to_previous = False
    # Keep footer empty on title page

    # ═══════════════════════════════════════════════════════════════════════════
    #  TABLE OF CONTENTS (no number per guidelines, but in sequence)
    # ═══════════════════════════════════════════════════════════════════════════
    sec_toc = add_new_section()
    heading_main("TABLE OF CONTENTS")

    toc_table = doc.add_table(rows=1, cols=3)
    toc_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(toc_table, color="000000", sz="4")

    # Header row
    hdr = toc_table.rows[0].cells
    hdr[0].width = Inches(1.0)
    hdr[1].width = Inches(4.0)
    hdr[2].width = Inches(1.5)
    for c in hdr:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    for c, t in zip(hdr, ["Sr. No.", "Content", "Page No."]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    toc_entries = [
        ("1", "Summer Training Certificate", "i"),
        ("2", "Declaration", "ii"),
        ("3", "Acknowledgement", "iii"),
        ("4", "List of Figures", "iv"),
        ("5", "List of Tables", "v"),
        ("6", "Training Objective", "1"),
        ("7", "Organization Brief", "2"),
        ("8", "Technology Used", "3-5"),
        ("9", "Software Model", "6-7"),
        ("10", "Project Details", "8-14"),
        ("11", "Project Screenshots with Explanations", "15-17"),
        ("12", "Bibliography", "18"),
    ]

    for sr, content, pg in toc_entries:
        row = toc_table.add_row()
        cells = row.cells
        cells[0].width = Inches(1.0)
        cells[1].width = Inches(4.0)
        cells[2].width = Inches(1.5)
        for c in cells:
            set_cell_margins(c, top=50, bottom=50, left=80, right=80)
        for c, t, align in [
            (cells[0], sr, WD_ALIGN_PARAGRAPH.CENTER),
            (cells[1], content, WD_ALIGN_PARAGRAPH.LEFT),
            (cells[2], pg, WD_ALIGN_PARAGRAPH.CENTER),
        ]:
            p = c.paragraphs[0]
            p.alignment = align
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    # ═══════════════════════════════════════════════════════════════════════════
    #  PRELIMINARY PAGES (Roman numerals: i, ii, iii, iv, v)
    # ═══════════════════════════════════════════════════════════════════════════

    # ── Page i: Summer Training Certificate ───────────────────────────────────
    sec_cert = add_new_section()
    set_page_start(sec_cert, 1, "lowerRoman")
    add_page_number_to_footer(sec_cert, "lowerRoman")

    heading_main("SUMMER TRAINING CERTIFICATE")
    spacer(12)
    body("This is to certify that the Summer Training Report entitled \u201CINTERA: A Karma-Driven Community Social Network Mobile Application\u201D submitted by Krish Sharma (Uni. Roll: 2411680) in partial fulfillment of the requirements for the award of the degree of Bachelor of Technology in Computer Science and Engineering at Amritsar Group of Colleges, Amritsar, is an authentic record of training work carried out by him under supervision.")
    body("The work embodies the results of original training undertaken during the prescribed training period and has not been submitted elsewhere for the award of any degree or diploma.")
    spacer(60)

    cert_sig_table = doc.add_table(rows=1, cols=2)
    cert_sig_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    remove_table_borders(cert_sig_table)
    sig_l = cert_sig_table.cell(0, 0)
    sig_r = cert_sig_table.cell(0, 1)
    sig_l.width = Inches(3.0)
    sig_r.width = Inches(3.0)

    p_sl = sig_l.paragraphs[0]
    p_sl.alignment = WD_ALIGN_PARAGRAPH.LEFT
    for line in ["________________________", "Head of Department", "Department of CSE"]:
        r = p_sl.add_run(line + "\n")
        r.font.name = 'Times New Roman'
        r.font.size = Pt(12)

    p_sr = sig_r.paragraphs[0]
    p_sr.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    for line in ["________________________", "Training Supervisor / Guide", "Department of CSE"]:
        r = p_sr.add_run(line + "\n")
        r.font.name = 'Times New Roman'
        r.font.size = Pt(12)

    spacer(36)
    p_seal = doc.add_paragraph()
    p_seal.alignment = WD_ALIGN_PARAGRAPH.CENTER
    _run(p_seal, "(Organization\u2019s Seal)", size=10, italic=True, color=(128, 128, 128))

    # ── Page ii: Declaration ──────────────────────────────────────────────────
    sec_decl = add_new_section()
    add_page_number_to_footer(sec_decl, "lowerRoman")

    heading_main("DECLARATION")
    spacer(6)
    body("I, the undersigned, solemnly declare that the Summer Training Report titled \u201CINTERA: A Karma-Driven Community Social Network Mobile Application\u201D is based on my own original work carried out during the summer training period. I affirm that the statements made and conclusions drawn in this report are the result of my independent research, software engineering, and implementation efforts.")

    body("I further certify that:")

    bullet("The work contained in this report is original and has been done entirely by me.", "1. ")
    bullet("This report has not been submitted to any other institution or university for the award of any degree, diploma, or certificate, either in India or abroad.", "2. ")
    bullet("I have strictly followed the academic guidelines provided by the department and college in preparing this report.", "3. ")
    bullet("Whenever material or code from open-source software or documentation has been used, appropriate credit has been given and full citations are provided in the bibliography.", "4. ")

    spacer(48)
    p_dec_sig = doc.add_paragraph()
    p_dec_sig.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p_dec_sig.paragraph_format.space_after = Pt(0)
    _run(p_dec_sig, "Krish Sharma", size=12, bold=True)
    p_dec_sig2 = doc.add_paragraph()
    p_dec_sig2.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    _run(p_dec_sig2, "(Uni. Roll: 2411680)", size=12)

    # ── Page iii: Acknowledgement ─────────────────────────────────────────────
    sec_ack = add_new_section()
    add_page_number_to_footer(sec_ack, "lowerRoman")

    heading_main("ACKNOWLEDGEMENT")
    spacer(6)
    body("It is my proud privilege to express my sincere gratitude to several persons who helped me directly or indirectly to conduct and successfully complete this Training and Project Work.")
    body("I express my heartfelt thanks and owe a deep sense of gratitude to my faculty mentors and project guides for their invaluable guidance, constant inspiration, and continuous feedback during the execution of this project.")
    body("I am extremely thankful to the Head of Department and all faculty members of the Computer Science & Engineering Department at Amritsar Group of Colleges, Amritsar for their kind guidance, administrative support, and encouragement throughout the training period.")
    body("I also wish to express my gratitude to my family and friends for their moral support and encouragement, which were instrumental in the successful completion of this work.")

    # ── Page iv: List of Figures ──────────────────────────────────────────────
    sec_lof = add_new_section()
    add_page_number_to_footer(sec_lof, "lowerRoman")

    heading_main("LIST OF FIGURES")
    spacer(6)

    fig_table = doc.add_table(rows=1, cols=3)
    fig_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(fig_table, color="000000", sz="4")

    fh = fig_table.rows[0].cells
    fh[0].width = Inches(1.0)
    fh[1].width = Inches(4.0)
    fh[2].width = Inches(1.5)
    for c in fh:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    for c, t in zip(fh, ["Figure No.", "Figure Name", "Page No."]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    fig_entries = [
        ("Fig. 1", "System Architecture Diagram", "6"),
        ("Fig. 2", "Data Flow Diagram (Level 0 & Level 1)", "7"),
        ("Fig. 3", "Entity Relationship / Data Model Diagram", "9"),
        ("Fig. 4", "App Home Feed Screenshot", "15"),
        ("Fig. 5", "Community Detail Page Screenshot", "16"),
        ("Fig. 6", "User Profile & Karma Screenshot", "16"),
        ("Fig. 7", "Spark Video Viewer Screenshot", "17"),
    ]

    for fno, fname, fpg in fig_entries:
        row = fig_table.add_row()
        cells = row.cells
        cells[0].width = Inches(1.0)
        cells[1].width = Inches(4.0)
        cells[2].width = Inches(1.5)
        for c in cells:
            set_cell_margins(c, top=50, bottom=50, left=80, right=80)
        for c, t, al in [
            (cells[0], fno, WD_ALIGN_PARAGRAPH.CENTER),
            (cells[1], fname, WD_ALIGN_PARAGRAPH.LEFT),
            (cells[2], fpg, WD_ALIGN_PARAGRAPH.CENTER),
        ]:
            p = c.paragraphs[0]
            p.alignment = al
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    # ── Page v: List of Tables ────────────────────────────────────────────────
    sec_lot = add_new_section()
    add_page_number_to_footer(sec_lot, "lowerRoman")

    heading_main("LIST OF TABLES")
    spacer(6)

    tbl_table = doc.add_table(rows=1, cols=3)
    tbl_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(tbl_table, color="000000", sz="4")

    th = tbl_table.rows[0].cells
    th[0].width = Inches(1.0)
    th[1].width = Inches(4.0)
    th[2].width = Inches(1.5)
    for c in th:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    for c, t in zip(th, ["Table No.", "Table Name", "Page No."]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    tbl_entries = [
        ("Table 1", "Technology Stack Summary", "3"),
        ("Table 2", "Hardware & Software Requirements", "5"),
        ("Table 3", "Users Collection Schema", "10"),
        ("Table 4", "Posts Collection Schema", "10"),
        ("Table 5", "Communities Collection Schema", "11"),
        ("Table 6", "Firebase Scalability Quotas", "14"),
    ]

    for tno, tname, tpg in tbl_entries:
        row = tbl_table.add_row()
        cells = row.cells
        cells[0].width = Inches(1.0)
        cells[1].width = Inches(4.0)
        cells[2].width = Inches(1.5)
        for c in cells:
            set_cell_margins(c, top=50, bottom=50, left=80, right=80)
        for c, t, al in [
            (cells[0], tno, WD_ALIGN_PARAGRAPH.CENTER),
            (cells[1], tname, WD_ALIGN_PARAGRAPH.LEFT),
            (cells[2], tpg, WD_ALIGN_PARAGRAPH.CENTER),
        ]:
            p = c.paragraphs[0]
            p.alignment = al
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    # ═══════════════════════════════════════════════════════════════════════════
    #  MAIN CONTENT PAGES (Arabic numerals: 1, 2, 3, ...)
    # ═══════════════════════════════════════════════════════════════════════════

    # ── Section 1: Training Objective ─────────────────────────────────────────
    sec_obj = add_new_section()
    set_page_start(sec_obj, 1, "decimal")
    add_page_number_to_footer(sec_obj, "decimal")

    heading_main("TRAINING OBJECTIVE")
    spacer(6)
    body("Industrial training and hands-on software development provide invaluable real-world exposure in specialized computing domains such as mobile application engineering, serverless cloud architecture, and machine learning integration. Practical project experience is essential because theoretical computer science concepts alone are insufficient to meet modern industry demands.")
    body("Industrial training serves as a critical bridge between academic learning and industry practices. While college education offers foundational knowledge of data structures, software design patterns, and programming languages, real-world software engineering projects expose students to actual client-side performance optimization, edge AI processing, cloud scaling, testing, and continuous deployment\u2014activities that form the backbone of industry software operations.")
    body("The key objectives of this training project include:")
    bullet("Applying theoretical computer science principles to real-time mobile and cloud application development.")
    bullet("Developing production-grade technical skills in Flutter, Dart, Firebase, and TensorFlow Lite.")
    bullet("Understanding client-server communication, serverless database modeling, and real-time state synchronization.")
    bullet("Implementing on-device edge AI algorithms for privacy-preserving content moderation.")
    bullet("Gaining insights into the software engineering lifecycle, code modularity, design documentation, and scalability testing.")

    # ── Section 2: Organization Brief ─────────────────────────────────────────
    sec_org = add_new_section()
    add_page_number_to_footer(sec_org, "decimal")

    heading_main("ORGANIZATION BRIEF")
    spacer(6)
    body("INTERA is a self-initiated, independent software engineering project conceived and developed as part of the Summer Training curriculum at Amritsar Group of Colleges, Amritsar. The project was carried out independently by the student under the guidance of the Department of Computer Science & Engineering.")
    body("The project was motivated by the growing need for safe, karma-driven community platforms that reward constructive participation rather than engagement-bait algorithmic loops. Unlike existing social media platforms, INTERA focuses on interest-aligned communities, peer reputation tracking through Karma Points, and on-device privacy-preserving content moderation using TensorFlow Lite.")
    body("The development environment utilized industry-standard tools including Visual Studio Code with Flutter/Dart extensions, Android Studio for emulator testing, Firebase Console for backend management, and Git/GitHub for version control. The entire application was built from scratch using Flutter (Dart) for the cross-platform frontend and Google Firebase for the serverless backend infrastructure.")

    # ── Section 3: Technology Used ────────────────────────────────────────────
    sec_tech = add_new_section()
    add_page_number_to_footer(sec_tech, "decimal")

    heading_main("TECHNOLOGY USED")
    spacer(6)

    # Table 1: Technology Stack Summary
    heading_sub("Table 1: Technology Stack Summary")

    tech_table = doc.add_table(rows=1, cols=3)
    tech_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(tech_table, color="000000", sz="4")

    tech_hdr = tech_table.rows[0].cells
    for c in tech_hdr:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    tech_hdr[0].width = Inches(1.0)
    tech_hdr[1].width = Inches(2.5)
    tech_hdr[2].width = Inches(3.0)

    for c, t in zip(tech_hdr, ["Sr. No.", "Technology", "Purpose"]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    tech_data = [
        ("1", "Flutter SDK (Dart 3.x)", "Cross-platform mobile UI framework"),
        ("2", "Firebase Authentication", "User identity management (Email, Google OAuth)"),
        ("3", "Cloud Firestore", "NoSQL real-time document database"),
        ("4", "Firebase Cloud Storage", "Media storage (images, videos, audio)"),
        ("5", "Firebase Cloud Functions", "Serverless backend triggers and tasks"),
        ("6", "Firebase Cloud Messaging", "Push notifications (FCM)"),
        ("7", "TensorFlow Lite", "On-device NSFW content moderation"),
        ("8", "SharedPreferences", "Local key-value storage for theme settings"),
        ("9", "Material Design 3", "UI widget design system"),
    ]

    for sr, tech, purpose in tech_data:
        row = tech_table.add_row()
        cells = row.cells
        cells[0].width = Inches(1.0)
        cells[1].width = Inches(2.5)
        cells[2].width = Inches(3.0)
        for c in cells:
            set_cell_margins(c, top=50, bottom=50, left=80, right=80)
        for c, t, al in [
            (cells[0], sr, WD_ALIGN_PARAGRAPH.CENTER),
            (cells[1], tech, WD_ALIGN_PARAGRAPH.LEFT),
            (cells[2], purpose, WD_ALIGN_PARAGRAPH.LEFT),
        ]:
            p = c.paragraphs[0]
            p.alignment = al
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    figure_caption("Table 1: Summary of technologies used in INTERA")

    heading_sub("Front End Technology")
    body("Flutter SDK (Dart 3.x) is Google\u2019s open-source UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase. INTERA uses Flutter\u2019s widget composition model with Material Design 3 specifications to deliver a consistent glassmorphic user interface across Android and iOS platforms.")
    body("State management is handled using ValueNotifier and Provider patterns, ensuring reactive UI updates and clean separation between business logic and presentation layers.")

    heading_sub("Back End & Cloud Technology")
    body("Firebase Authentication handles secure user identity management via email/password tokens and Google Sign-In OAuth. Cloud Firestore serves as the primary NoSQL document database, keeping mobile client data synchronized in real-time with offline persistence support.")
    body("Firebase Cloud Storage provides scalable object storage for user-uploaded media including high-resolution images, profile avatars, video sparks, and audio echoes. Firebase Cloud Functions (Node.js) handle serverless backend operations including database triggers and push notification dispatch via Firebase Cloud Messaging (FCM).")

    heading_sub("On-Device Artificial Intelligence")
    body("TensorFlow Lite (tflite_flutter) enables local execution of the nsfw_detector.tflite model for edge-based content moderation. Images are resized to 224\u00d7224 pixels and classified on-device before upload, preserving user privacy and eliminating server-side processing latency. A skin-tone density heuristic fallback (flagging >38% skin pixel density) activates if the TFLite model is unavailable.")

    # Table 2: Hardware & Software Requirements
    heading_sub("Table 2: Hardware and Software Requirements")

    req_table = doc.add_table(rows=1, cols=2)
    req_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(req_table, color="000000", sz="4")

    req_hdr = req_table.rows[0].cells
    for c in req_hdr:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    req_hdr[0].width = Inches(3.0)
    req_hdr[1].width = Inches(3.5)
    for c, t in zip(req_hdr, ["Requirement", "Specification"]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    req_data = [
        ("Processor", "Intel Core i5 / AMD Ryzen 5 or higher"),
        ("RAM", "Minimum 8 GB (16 GB recommended)"),
        ("Storage", "256 GB SSD (512 GB recommended)"),
        ("OS (Development)", "Windows 10/11 (64-bit), macOS, or Linux"),
        ("Android Target", "Android 7.0 (API Level 24) or higher"),
        ("iOS Target", "iOS 12.0 or higher"),
        ("Flutter SDK", "Version 3.19.x or higher"),
        ("Dart SDK", "Version 3.3.x or higher"),
        ("Node.js", "Version 18.x (for Cloud Functions)"),
        ("IDE", "VS Code / Android Studio with Flutter extensions"),
    ]

    for req, spec in req_data:
        row = req_table.add_row()
        cells = row.cells
        cells[0].width = Inches(3.0)
        cells[1].width = Inches(3.5)
        for c in cells:
            set_cell_margins(c, top=50, bottom=50, left=80, right=80)
        for c, t in [(cells[0], req), (cells[1], spec)]:
            p = c.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    figure_caption("Table 2: Hardware and software requirements for development and deployment")

    # ── Section 4: Software Model ─────────────────────────────────────────────
    sec_model = add_new_section()
    add_page_number_to_footer(sec_model, "decimal")

    heading_main("SOFTWARE MODEL")
    spacer(6)

    heading_sub("System Architecture")
    body("The INTERA system architecture consists of three primary layers: (1) Client Presentation Layer \u2014 the Flutter mobile app handling UI rendering, route navigation, theme management, and local state; (2) Identity Gateway \u2014 Firebase Authentication providing secure sign-in via email/password and Google OAuth; and (3) Serverless Cloud Backend \u2014 Cloud Firestore for document storage, Cloud Storage for media, Cloud Functions for background triggers, and FCM for push notifications.")
    body("An additional on-device ML layer runs TensorFlow Lite models directly in device memory for instant NSFW media classification before upload, ensuring privacy-preserving content safety without cloud dependency.")

    # Fig 1 placeholder
    fig1_table = doc.add_table(rows=1, cols=1)
    fig1_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    fig1_cell = fig1_table.cell(0, 0)
    fig1_cell.width = Inches(5.5)
    set_cell_shading(fig1_cell, "F8F9FA")
    set_cell_margins(fig1_cell, top=200, bottom=200, left=200, right=200)
    fp1 = fig1_cell.paragraphs[0]
    fp1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    _run(fp1, "[ SYSTEM ARCHITECTURE DIAGRAM ]", size=10, italic=True, color=(100, 100, 100))
    figure_caption("Fig. 1: INTERA System Architecture Diagram")

    heading_sub("Data Flow Diagram (DFD)")
    body("Level 0 DFD: The user interacts with the Flutter Client Interface by submitting post content, media, or authentication credentials. The system processes inputs against the Local Edge AI filter and Firebase Identity Gateway, returning authenticated access and filtered content streams.")
    body("Level 1 DFD: Illustrates detailed data movement between the User Profile Module, Feed Processing Algorithm, NSFW AI Detector, Cloud Storage Bucket, and Firestore Database Collections. Each module communicates through well-defined service interfaces within the Flutter codebase.")

    # Fig 2 placeholder
    fig2_table = doc.add_table(rows=1, cols=1)
    fig2_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    fig2_cell = fig2_table.cell(0, 0)
    fig2_cell.width = Inches(5.5)
    set_cell_shading(fig2_cell, "F8F9FA")
    set_cell_margins(fig2_cell, top=200, bottom=200, left=200, right=200)
    fp2 = fig2_cell.paragraphs[0]
    fp2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    _run(fp2, "[ DATA FLOW DIAGRAM (LEVEL 0 & LEVEL 1) ]", size=10, italic=True, color=(100, 100, 100))
    figure_caption("Fig. 2: Data Flow Diagram (Level 0 and Level 1)")

    # ── Section 5: Project Details ────────────────────────────────────────────
    sec_details = add_new_section()
    add_page_number_to_footer(sec_details, "decimal")

    heading_main("PROJECT DETAILS")
    spacer(6)

    heading_sub("5.1 Introduction")
    body("INTERA is a karma-driven community social network mobile application designed to connect users based on shared interests, skills, and positive digital interactions. The platform empowers users to publish posts, stream video sparks, build topic-focused communities, and earn Karma Points for constructive participation.")
    body("The tagline of the application is \u201CAsk. Answer. Earn Karma.\u201D which encapsulates the core philosophy of rewarding meaningful contributions over passive consumption.")

    heading_sub("5.2 Key Features")
    bullet("Karma-Driven Community Feed: Personalized post feeds filtered by user interest tags, following status, and engagement metrics using a weighted scoring algorithm.")
    bullet("Spark Video & Echo Viewer: Full-screen video and audio stream experience with gesture controls, like counter updates, and comment threads.")
    bullet("On-Device Edge NSFW Filtering: Real-time neural network classification on media assets prior to cloud storage upload.")
    bullet("Firebase Authentication Gateway: Secure sign-in via Email/Password and Google OAuth with persistent session handling and email verification.")
    bullet("Community Hub & Detail Pages: Creation and discovery of niche communities with member lists, pinned posts, and custom banners.")
    bullet("Push Notification System: Instant device alerts powered by FCM for likes, comments, follower additions, messages, and system notices.")
    bullet("Dynamic Glassmorphic Theme Engine: Custom dark/light mode palette built with Flutter Material 3 and ValueNotifier-based reactive switching.")
    bullet("Real-Time Messaging: Private conversations with message request flow, read receipts, and typing indicators.")

    heading_sub("5.3 Database & Schema Details")
    body("INTERA utilizes Google Cloud Firestore organized into primary document collections. Each collection is modeled with Dart classes that serialize/deserialize Firestore documents.")

    # Table 3: Users schema
    heading_sub("Table 3: Users Collection Schema")
    users_table = doc.add_table(rows=1, cols=3)
    users_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(users_table, color="000000", sz="4")

    uh = users_table.rows[0].cells
    for c in uh:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    uh[0].width = Inches(2.0)
    uh[1].width = Inches(1.5)
    uh[2].width = Inches(3.0)
    for c, t in zip(uh, ["Field Name", "Data Type", "Description"]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    users_data = [
        ("id", "String (PK)", "Unique Firebase Auth UID"),
        ("name", "String", "User\u2019s full display name"),
        ("username", "String", "Unique handle (e.g., @krish)"),
        ("bio", "String", "Short biography"),
        ("avatarUrl", "String", "Cloud Storage URL for profile picture"),
        ("karmaPoints", "Integer", "Accumulated community reputation score"),
        ("followersCount", "Integer", "Number of followers"),
        ("followingCount", "Integer", "Number of users being followed"),
        ("skills", "List<String>", "User-listed skill/interest tags"),
        ("isAnonymous", "Boolean", "Anonymous posting flag"),
    ]

    for fname, dtype, desc in users_data:
        row = users_table.add_row()
        cells = row.cells
        cells[0].width = Inches(2.0)
        cells[1].width = Inches(1.5)
        cells[2].width = Inches(3.0)
        for c in cells:
            set_cell_margins(c, top=40, bottom=40, left=80, right=80)
        for c, t in [(cells[0], fname), (cells[1], dtype), (cells[2], desc)]:
            p = c.paragraphs[0]
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    figure_caption("Table 3: Schema for the users collection in Cloud Firestore")

    # Table 4: Posts schema
    heading_sub("Table 4: Posts Collection Schema")
    posts_table = doc.add_table(rows=1, cols=3)
    posts_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(posts_table, color="000000", sz="4")

    ph = posts_table.rows[0].cells
    for c in ph:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    ph[0].width = Inches(2.0)
    ph[1].width = Inches(1.5)
    ph[2].width = Inches(3.0)
    for c, t in zip(ph, ["Field Name", "Data Type", "Description"]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    posts_data = [
        ("id", "String (PK)", "Unique post identifier"),
        ("authorId", "String (FK)", "Reference to users.id"),
        ("title", "String", "Post heading title"),
        ("body", "String", "Detailed post text content"),
        ("imageUrl", "String", "Cloud Storage media URL"),
        ("type", "PostType", "Post type enum (text, image, video, echo, audio)"),
        ("likeCount", "Integer", "Total positive engagement count"),
        ("commentCount", "Integer", "Total comment responses"),
        ("tags", "List<String>", "Interest/skill tags for feed ranking"),
        ("rewardKarma", "Integer", "Karma point value assigned to post"),
        ("communityId", "String (FK)", "Associated community ID"),
        ("createdAt", "Timestamp", "Publication timestamp"),
    ]

    for fname, dtype, desc in posts_data:
        row = posts_table.add_row()
        cells = row.cells
        cells[0].width = Inches(2.0)
        cells[1].width = Inches(1.5)
        cells[2].width = Inches(3.0)
        for c in cells:
            set_cell_margins(c, top=40, bottom=40, left=80, right=80)
        for c, t in [(cells[0], fname), (cells[1], dtype), (cells[2], desc)]:
            p = c.paragraphs[0]
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    figure_caption("Table 4: Schema for the posts collection in Cloud Firestore")

    # Table 5: Communities schema
    heading_sub("Table 5: Communities Collection Schema")
    comm_table = doc.add_table(rows=1, cols=3)
    comm_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(comm_table, color="000000", sz="4")

    ch = comm_table.rows[0].cells
    for c in ch:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    ch[0].width = Inches(2.0)
    ch[1].width = Inches(1.5)
    ch[2].width = Inches(3.0)
    for c, t in zip(ch, ["Field Name", "Data Type", "Description"]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    comm_data = [
        ("id", "String (PK)", "Community identifier"),
        ("name", "String", "Community title name"),
        ("description", "String", "Community goal statement"),
        ("creatorId", "String (FK)", "Founder user ID"),
        ("memberIds", "List<String>", "Member user IDs list"),
        ("createdAt", "Timestamp", "Creation timestamp"),
    ]

    for fname, dtype, desc in comm_data:
        row = comm_table.add_row()
        cells = row.cells
        cells[0].width = Inches(2.0)
        cells[1].width = Inches(1.5)
        cells[2].width = Inches(3.0)
        for c in cells:
            set_cell_margins(c, top=40, bottom=40, left=80, right=80)
        for c, t in [(cells[0], fname), (cells[1], dtype), (cells[2], desc)]:
            p = c.paragraphs[0]
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    figure_caption("Table 5: Schema for the communities collection in Cloud Firestore")

    heading_sub("5.4 Core Source Code")
    body("This section contains representative source code snippets from the INTERA Flutter application demonstrating the core architecture.")

    # Code: main.dart
    code_block("lib/main.dart", """import 'package:flutter/material.dart';
import 'core/constants/strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/custom_scaffold_messenger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.initTheme();
  runApp(const InteraApp());
}

class InteraApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  const InteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: AppStrings.appName,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentMode,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}""")

    # Code: feed_algorithm.dart
    code_block("lib/core/services/feed_algorithm.dart", """class FeedAlgorithm {
  static const double _wFollowing = 40;
  static const double _wLiked     = 30;
  static const double _wSaved     = 25;
  static const double _wTagMatch  = 20;
  static const double _wLikes     = 15;
  static const double _wComments  = 10;
  static const double _wDecay     = 25;
  static const double _wSeen      = 50;

  static List<Post> rankPosts(List<Post> posts, UserFeedProfile profile) {
    final followingPosts = <_ScoredPost>[];
    final discoveryPosts = <_ScoredPost>[];
    for (final post in posts) {
      final sp = _ScoredPost(post, _score(post, profile));
      if (profile.followingIds.contains(post.authorId)) {
        followingPosts.add(sp);
      } else {
        discoveryPosts.add(sp);
      }
    }
    followingPosts.sort((a, b) => b.score.compareTo(a.score));
    discoveryPosts.sort((a, b) => b.score.compareTo(a.score));
    return [
      ...followingPosts.map((sp) => sp.post),
      ...discoveryPosts.map((sp) => sp.post),
    ];
  }

  static double _score(Post post, UserFeedProfile profile) {
    double s = 5;
    if (profile.followingIds.contains(post.authorId)) s += _wFollowing;
    if (profile.likedPostIds.contains(post.id)) s += _wLiked;
    if (profile.savedPostIds.contains(post.id)) s += _wSaved;
    if (post.tags.isNotEmpty) {
      final matches = post.tags.map((t) => t.toLowerCase()).toSet()
          .intersection(profile.interestTags).length;
      s += _wTagMatch * matches.clamp(0, 3);
    }
    s += (post.likeCount / 10).clamp(0, _wLikes);
    final ageHours = DateTime.now().difference(post.createdAt).inHours;
    s -= (ageHours / (7 * 24)).clamp(0.0, 1.0) * _wDecay;
    if (profile.seenPostIds.contains(post.id)) s -= _wSeen;
    return s;
  }
}""")

    # Code: auth_service.dart
    code_block("lib/core/services/auth_service.dart", """class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserCredential> signIn(
      {required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password.trim());
  }

  Future<UserCredential> signUp(
      {required String email, required String password}) {
    return _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password.trim());
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}""")

    # Code: nsfw_detection_service.dart
    code_block("lib/core/services/nsfw_detection_service.dart", """class NsfwDetectionService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/models/nsfw_detector.tflite');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading TFLite model: \\$e');
    }
  }

  static Future<bool> isImageSafe(File imageFile) async {
    if (!_isInitialized) await init();
    if (_interpreter != null) {
      return await _runTfliteInference(imageFile);
    }
    return _skinToneFallbackAnalysis(imageFile);
  }

  static Future<bool> _runTfliteInference(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return true;
    final resized = img.copyResize(decoded, width: 224, height: 224);
    var input = Float32List(1 * 224 * 224 * 3);
    var idx = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resized.getPixel(x, y);
        input[idx++] = pixel.r / 255.0;
        input[idx++] = pixel.g / 255.0;
        input[idx++] = pixel.b / 255.0;
      }
    }
    var output = List.filled(1 * 2, 0.0).reshape([1, 2]);
    _interpreter!.run(input.buffer.asFloat32List(), output);
    return output[0][1] < 0.70; // NSFW threshold
  }
}""")

    heading_sub("5.5 Scalability Analysis")

    # Table 6: Firebase Scalability
    heading_sub("Table 6: Firebase Scalability Quotas")

    scale_table = doc.add_table(rows=1, cols=3)
    scale_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(scale_table, color="000000", sz="4")

    sh = scale_table.rows[0].cells
    for c in sh:
        set_cell_shading(c, "D9D9D9")
        set_cell_margins(c, top=60, bottom=60, left=80, right=80)
    sh[0].width = Inches(2.0)
    sh[1].width = Inches(2.0)
    sh[2].width = Inches(2.5)
    for c, t in zip(sh, ["Service", "Default Quota", "User Capacity"]):
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(t)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(10)
        r.font.bold = True

    scale_data = [
        ("Authentication", "100M+ users", "Unlimited active sign-ins"),
        ("Firestore Connections", "1,000,000 concurrent", "10\u201320M MAUs"),
        ("Firestore Writes", "10,000 writes/sec", "Hundreds of txns/sec"),
        ("Cloud Storage", "Auto-scaling", "Exabytes of media"),
        ("FCM", "Billions of msgs/day", "Millions of active users"),
    ]

    for svc, quota, cap in scale_data:
        row = scale_table.add_row()
        cells = row.cells
        cells[0].width = Inches(2.0)
        cells[1].width = Inches(2.0)
        cells[2].width = Inches(2.5)
        for c in cells:
            set_cell_margins(c, top=40, bottom=40, left=80, right=80)
        for c, t in [(cells[0], svc), (cells[1], quota), (cells[2], cap)]:
            p = c.paragraphs[0]
            r = p.add_run(t)
            r.font.name = 'Times New Roman'
            r.font.size = Pt(10)

    figure_caption("Table 6: Firebase scalability quotas and estimated user capacity")

    body("While the backend is serverless and auto-scales, two architectural bottlenecks exist: (1) Client-Side Feed Ranking currently loads all posts for scoring; at scale, this should migrate to server-side feed generation with cursor-based pagination. (2) Single-Document Hot-Spot Write Limits on viral posts require distributed counter shards to prevent Firestore write contention.")

    # ── Section 6: Project Screenshots with Explanations ──────────────────────
    sec_ss = add_new_section()
    add_page_number_to_footer(sec_ss, "decimal")

    heading_main("PROJECT SCREENSHOTS WITH EXPLANATIONS")
    spacer(6)

    screenshots = [
        ("Fig. 4: App Home Feed Page",
         "The home feed displays karma-ranked community posts filtered by user interest tags. Users can browse posts from followed users and discover new content. Each post card shows the author avatar, title, body preview, reaction counts, and skill tags. The glassmorphic card design adapts seamlessly between dark and light themes."),
        ("Fig. 5: Community Detail Page",
         "This screen presents a detailed view of a specific community including member count, community description, creator information, and a feed of posts published within the community. Users can join/leave communities and publish posts directly from this screen."),
        ("Fig. 6: User Profile & Karma Screen",
         "The user profile screen showcases the user\u2019s avatar, display name, username, bio, total Karma Points earned, followers/following counts, and listed skill badges. Users can edit their profile, view their own posts, and manage account settings from this page."),
        ("Fig. 7: Spark Video Viewer Screen",
         "A full-screen, vertically-scrollable video viewer similar to modern short-form video platforms. Supports gesture-based navigation between sparks, real-time like/comment interactions, and author profile quick-view. Videos auto-play on entry and pause when scrolled away."),
    ]

    for fig_title, fig_desc in screenshots:
        heading_sub(fig_title)
        # Screenshot placeholder
        ss_table = doc.add_table(rows=1, cols=1)
        ss_table.alignment = WD_TABLE_ALIGNMENT.CENTER
        ss_cell = ss_table.cell(0, 0)
        ss_cell.width = Inches(4.0)
        set_cell_shading(ss_cell, "F0F0F0")
        set_cell_margins(ss_cell, top=250, bottom=250, left=200, right=200)
        sp = ss_cell.paragraphs[0]
        sp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        _run(sp, f"[ SCREENSHOT: {fig_title.upper()} ]", size=10, italic=True, color=(120, 120, 120))

        figure_caption(fig_title)
        body(fig_desc)

    # ── Section 7: Bibliography ───────────────────────────────────────────────
    sec_bib = add_new_section()
    add_page_number_to_footer(sec_bib, "decimal")

    heading_main("BIBLIOGRAPHY")
    spacer(6)

    heading_sub("Books")
    bib_books = [
        '[1] E. Windmill, Flutter in Action, 1st ed., Manning Publications, 2020.',
        '[2] A. Rischpater, Application Development with Cloud Functions for Firebase, 1st ed., Packt Publishing, 2021.',
        '[3] M. Abadi et al., TensorFlow: Large-Scale Machine Learning on Heterogeneous Systems, Google Research, 2015.',
    ]
    for entry in bib_books:
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.left_indent = Inches(0.5)
        p.paragraph_format.first_line_indent = Inches(-0.5)
        _run(p, entry, size=12)

    heading_sub("Websites")
    bib_websites = [
        '[4] Google, "Flutter Documentation," Flutter Dev, 2024. [Online]. Available: https://docs.flutter.dev/. [Accessed: Jul. 15, 2026].',
        '[5] Google, "Firebase Documentation," Firebase, 2024. [Online]. Available: https://firebase.google.com/docs/. [Accessed: Jul. 15, 2026].',
        '[6] Google, "Dart Programming Language," Dart Dev, 2024. [Online]. Available: https://dart.dev/guides. [Accessed: Jul. 15, 2026].',
        '[7] Google, "TensorFlow Lite Guide," TensorFlow, 2024. [Online]. Available: https://www.tensorflow.org/lite/guide. [Accessed: Jul. 15, 2026].',
        '[8] Google, "Material Design 3 Guidelines," Material Design, 2024. [Online]. Available: https://m3.material.io/. [Accessed: Jul. 15, 2026].',
        '[9] Google, "Cloud Firestore Data Modeling," Firebase, 2024. [Online]. Available: https://firebase.google.com/docs/firestore/manage-data/structure-data. [Accessed: Jul. 15, 2026].',
    ]
    for entry in bib_websites:
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.left_indent = Inches(0.5)
        p.paragraph_format.first_line_indent = Inches(-0.5)
        _run(p, entry, size=12)

    # ═══════════════════════════════════════════════════════════════════════════
    #  SAVE
    # ═══════════════════════════════════════════════════════════════════════════
    output_path = "d:/Intera/INTERA_Summer_Training_Report.docx"
    doc.save(output_path)
    print(f"Report generated successfully: {output_path}")


if __name__ == "__main__":
    build_report()
