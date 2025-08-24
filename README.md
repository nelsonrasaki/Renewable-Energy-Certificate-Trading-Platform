# Renewable Energy Certificate Trading Platform

A decentralized platform for trading renewable energy certificates (RECs) built on the Stacks blockchain using Clarity smart contracts.

## System Overview

This platform enables the verification, issuance, trading, and compliance tracking of renewable energy certificates. It supports both solar and wind energy generation with comprehensive carbon footprint calculations.

## Architecture

The system consists of five core smart contracts:

### 1. Energy Generation Verification (`energy-verification.clar`)
- Verifies solar and wind energy generation data
- Validates generation sources and capacity
- Maintains generation history and metrics
- Supports multiple renewable energy types

### 2. Certificate Management (`certificate-manager.clar`)
- Issues renewable energy certificates (RECs)
- Tracks certificate ownership and transfers
- Manages certificate metadata and validity
- Handles certificate retirement and cancellation

### 3. Trading Marketplace (`trading-marketplace.clar`)
- Facilitates REC trading between parties
- Manages buy/sell orders and price discovery
- Handles escrow and settlement
- Tracks trading volume and market metrics

### 4. Compliance Reporting (`compliance-reporting.clar`)
- Tracks renewable energy mandates and requirements
- Generates compliance reports for organizations
- Manages regulatory reporting periods
- Validates compliance status and penalties

### 5. Carbon Footprint Calculator (`carbon-calculator.clar`)
- Calculates carbon offsets from renewable energy
- Tracks emission reductions and environmental impact
- Manages carbon credit conversions
- Provides sustainability metrics

## Key Features

- **Decentralized Verification**: Trustless verification of energy generation data
- **Transparent Trading**: Open marketplace for REC trading with price discovery
- **Compliance Automation**: Automated compliance tracking and reporting
- **Carbon Impact**: Real-time carbon footprint calculations and offset tracking
- **Multi-Energy Support**: Support for solar, wind, and other renewable sources

## Data Types

### Energy Generation Record
- Generator ID and type (solar/wind)
- Generation amount (MWh)
- Timestamp and location
- Verification status

### Renewable Energy Certificate
- Unique certificate ID
- Associated generation record
- Owner principal
- Issuance and expiration dates
- Trading status

### Trading Order
- Order ID and type (buy/sell)
- Certificate requirements
- Price and quantity
- Order status and expiration

### Compliance Report
- Reporting entity
- Compliance period
- Required vs actual renewable energy
- Compliance status and penalties

## Getting Started

1. Deploy the contracts in the following order:
    - energy-verification.clar
    - certificate-manager.clar
    - trading-marketplace.clar
    - compliance-reporting.clar
    - carbon-calculator.clar

2. Initialize the system with authorized verifiers and administrators

3. Register energy generators and begin verification process

4. Issue certificates for verified generation

5. Enable trading and compliance reporting

## Testing

Run the test suite using Vitest:

\`\`\`bash
npm test
\`\`\`

Tests cover all contract functions, edge cases, and integration scenarios.

