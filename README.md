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

## Repository Structure

