# PROJECT_MEMORY.md

> Last Updated: 2026-07-25

---

# Project

**Working Name:** Atlas

**Project Type:** AI-Native Reading Platform

Current objective is **not** to build a commercial product immediately.

The immediate goal is to build the best personal reading application possible. If the result is good enough, it may later evolve into a public product.

---

# Vision

Build the world's smartest reading platform where technology improves the reading experience instead of distracting from it.

The platform should prioritize:

* Reader immersion
* Offline-first experience
* Beautiful UI
* Performance
* AI only where it provides real value

AI should assist readers—not become the product.

---

# Product Philosophy

The application should always answer:

> "Does this improve the reading experience?"

If not, reconsider the feature.

Reader experience always takes priority over feature count.

---

# Reader Pain Points (Validated)

## R-001

Chinese (Pinyin) names are difficult to remember.

Problems:

* Similar names
* Hundreds of recurring characters
* Long novels
* Readers forget who people are

Potential solutions:

* Character cards
* Character memory
* Personal aliases
* Relationship graph
* Story recap

Priority:

★★★★★

---

## R-002

Intrusive advertisements ruin immersion.

Problems:

* Ads between every chapter
* Reading flow interrupted
* Readers install ad blockers
* Readers abandon apps

Product principle:

Never interrupt an active reading session.

Priority:

★★★★★

---

# Product Principles

1. Reader experience comes before feature count.
2. Offline-first.
3. AI assists.
4. AI never blocks reading.
5. Performance before animation.
6. Every feature must solve a validated pain point.
7. Architecture before implementation.
8. Consistency over speed.
9. Reusable AI context.
10. Documentation is part of the product.

---

# Long-Term Vision

Potential future expansion:

* Creator platform
* AI writing tools
* Community
* Recommendations
* Marketplace
* Premium subscription
* Licensing
* Translation support

These are **not** MVP goals.

---

# Architecture Decisions

## Mobile/Desktop

Flutter

Targets:

* Android
* iOS
* Windows
* Web (future-ready)

---

## Backend

Next.js backend services.

Web frontend is not currently part of scope.

---

## State Management

Riverpod

Decision:

Riverpod chosen over Bloc for consistency, reduced boilerplate, and better AI-generated code maintainability.

---

## Database

PostgreSQL

Use PostgreSQL Full-Text Search initially.

---

## AI

Hybrid architecture.

Support:

* Cloud APIs
* Self-hosted models
* BYOK (Bring Your Own Key)

All AI traffic goes through an AI Gateway.

---

## Deployment

Docker

Coolify

Self-host friendly.

---

# Engineering Philosophy

The project should be architecture-driven.

The blueprint becomes the source of truth.

Code follows documentation—not the other way around.

---

# Engineering Operating System (EOS)

The project consists of two repositories.

## atlas-blueprint

Contains:

* Vision
* Product
* Architecture
* Standards
* AI agents
* ADRs
* Templates
* Documentation

Contains **no application code**.

---

## atlas-app

Contains:

* Flutter application
* Backend
* Infrastructure
* Tests

Application code only.

---

# AI Development Philosophy

AI should never receive the entire repository.

Instead it should receive only the relevant context.

Context hierarchy:

Vision

↓

Architecture

↓

Domain

↓

Feature

↓

Task

↓

Implementation

---

# AI Agent Philosophy

Each module has a dedicated AI agent.

Examples:

* Reader
* Authentication
* Library
* Recommendation
* Search
* Analytics
* Notifications
* Storage
* AI
* Database

Each agent owns only its domain.

---

# Documentation Strategy

Rather than manually maintaining hundreds of documents, maintain one master specification that can generate the blueprint repository.

The specification becomes the engineering source of truth.

---

# Development Workflow

Idea

↓

Research

↓

Pain Point

↓

Requirement

↓

Architecture

↓

Specification

↓

Implementation

↓

Testing

↓

Review

↓

Documentation

↓

Release

---

# Future Documents

Planned:

* EOS Specification
* Constitution
* Manifest
* Software Architecture Document
* Product Requirement Document
* ADR Library
* AI Agent Library
* Prompt Library
* Engineering Standards

---

# Immediate Goal

Do **not** rush into coding.

Build a solid engineering foundation first.

Then implement the application incrementally, validating features against real reader pain points.

---

# Guiding Statement

> Build the reading application you personally want to use every day. If it genuinely solves your own problems, it has a much stronger chance of solving them for others.
