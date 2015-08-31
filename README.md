# SuiteCRM Puppet Module

## Installs and configures SuiteCRM (beta test. Configuration is not happening yet.)

[![Build Status](https://travis-ci.org/PierrickI3/pierrickl-suitecrm.svg?branch=master)](https://travis-ci.org/PierrickI3/pierrickl-suitecrm)

[![Coverage Status](https://coveralls.io/repos/PierrickI3/pierrickl-suitecrm/badge.svg)](https://coveralls.io/r/PierrickI3/pierrickl-suitecrm)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the modules do and why it is useful](#module-description)
3. [Setup - The basics of getting started with suitecrm](#setup)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

Installs and configures SuiteCRM silently.

## Module Description

## Setup

### What install affects

* Installs and configures SuiteCRM.

### Setup Requirements

Windows 8.1, 2012 or 2012R2

### Beginning

## Usage

```puppet
class { 'suitecrm':
    ensure  => installed,
    phppath => 'C:/PHP',
}
```

## Reference

Here, list the classes, types, providers, facts, etc contained in your module.
This section should include all of the under-the-hood workings of your module so
people know what the module is touching on their system but don't need to mess
with things. (We are working on automating this section!)

## Limitations

Only compatible with Windows 8, 2012 or 2012R2
Tested with Windows 2012 R2

## Development

## Release Notes