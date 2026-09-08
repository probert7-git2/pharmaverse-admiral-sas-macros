# SAS Macros Mirroring Pharmaverse Admiral for ADaM Safety Dataset Construction

This repository contains the full set of SAS macros, programs, documentation, and validation artifacts developed during a project that used **Cursor AI** to reverse‑engineer and replicate key *Pharmaverse Admiral* functions. The goal was to create ADaM safety‑related datasets from CDISC SDTM data using SAS, following the same logic implemented in the R `{admiral}` package.

The resulting SAS macros provide a **1:1 functional analogue** to the corresponding Pharmaverse Admiral functions and were validated against the official Pharmaverse ADaM datasets.

---

## Project Overview

Pharmaverse Admiral provides a robust R-based framework for generating ADaM datasets. This project demonstrates that modern AI-assisted programming can translate that logic into SAS macros that:

- Mirror Admiral function behavior  
- Produce ADaM datasets consistent with Pharmaverse outputs  
- Support safety‑related domains commonly used in clinical trials  

All SAS programming was performed using **SAS On‑Demand for Academics (ODA)**.

---

## ADaM Datasets Produced

The AI-generated SAS macros and programs construct the following ADaM safety datasets:

- **ADSL** — Subject-Level Analysis Dataset  
- **ADAE** — Adverse Events  
- **ADCM** — Concomitant Medications  
- **ADVS** — Vital Signs  
- **ADEG** — ECG  
- **ADLB** — Laboratory Data  

Each dataset is built from the **Pharmaverse SDTM source data**, ensuring consistency with the R-based reference implementation.

---
Repository Structure
This repository is organized into several directories that contain SAS macros, programs, documentation, metadata, and validation artifacts used throughout the project.

docs/
Contains:

The slide deck used in the presentation (PDF format)

Markdown documentation describing:

How each ADaM dataset was constructed

Issues encountered and resolved during SAS macro development

Notes on Admiral logic and PVA (Pharmaverse Admiral) terminology

macros/
AI-generated SAS macros that replicate Pharmaverse Admiral functions.
All macro names begin with:

Code
%m_<admiral_function_name>
Shortened names are used when necessary.

programs/
Executable SAS programs that call the macros to produce each ADaM dataset.

metadata/
Metadata artifacts including:

Variable inventories

Derivation registries

Source-to-target traceability

“As programmed” specifications (CSV)

validation/
Multiple validation approaches were used:

Golden Subjects
Synthetic subjects designed to test:

Missing data patterns

Boundary conditions

Overlapping events

Unscheduled visits

Edge-case logic

Edge Cases
Targeted tests for boundary limits and unusual clinical scenarios.

As Programmed Specifications
CSV files generated from the SAS programs.
These were intended to be compared with Pharmaverse ADaM specifications, but the official specs could not be located.

Comparison Against Pharmaverse ADaM
The official Pharmaverse ADaM datasets were used as the gold standard for validating the SAS outputs.

Data Sources
All SDTM and ADaM reference datasets were obtained from the Pharmaverse website:

SDTM datasets → used as input

ADaM datasets → used as reference outputs for validation

This ensures that the SAS macros were tested against authoritative, community-maintained datasets.

Purpose of This Repository
This project demonstrates:

The feasibility of AI-assisted SAS macro generation

The ability to mirror complex R functions in SAS

A reproducible workflow for building ADaM safety datasets

A validation framework that ensures reliability and traceability

It also provides a foundation for future work expanding into efficacy datasets, oncology endpoints, and broader pharmaverse alignment.

How to Use This Repository
Review the docs/ folder for conceptual background and dataset-specific notes.

Explore the macros/ directory to see the AI-generated SAS implementations.

Run the programs in programs/ on SAS ODA to generate ADaM datasets.

Examine validation/ outputs to understand how the SAS results compare to Pharmaverse ADaM.

Contact
For questions or collaboration inquiries, please reach out via GitHub or email.


