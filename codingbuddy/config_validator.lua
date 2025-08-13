#!/usr/bin/env lua

-- config_validator.lua - Configuration validation and sanitization module
-- Part of CodingBuddy - Professional code analysis and conversation management
--
-- This module provides comprehensive validation for CodingBuddy configuration files,
-- ensuring security, correctness, and proper defaults are maintained.
--
-- Author: CodingBuddy Development Team
-- Version: 1.0.0
-- License: MIT

local config_validator = {}

-- Module metadata
config_validator._VERSION = "1.0.0"
config_validator._DESCRIPTION = "Configuration validation and sanitization for CodingBuddy"
config_validator._URL = "https://github.com/codingbuddy/config-validator"

-- Dependencies
local utils = require('utils')

-- Configuration schema definition with validation rules
local CONFIG_SCHEMA = {
    -- Core application settings
    app = {
        name = {type = "string", required = true, default = "CodingBuddy"},
        version = {type = "string", required = true, pattern = "^%d+%.%d+%.%d+"},
        debug_mode = {type = "boolean", default = false},
        log_level = {type = "string", default = "info", enum = {"debug", "info", "warn", "error"}},
        max_memory_mb = {type = "number", default = 512, min = 128, max = 4096}
    },

    -- Security and encryption settings
    security = {
        conversation_encryption = {type = "boolean", default = true},
        encryption_algorithm = {type = "string", default = "AES-256-CBC",
                              enum = {"AES-256-CBC", "AES-256-GCM"}},
        key_derivation_iterations = {type = "number", default = 100000, min = 10000},
        secure_delete = {type = "boolean", default = true},
        session_timeout_minutes = {type = "number", default = 30, min = 5, max = 480}
    },

    -- AI and conversation settings
    ai = {
        default_model = {type = "string", default = "gpt-3.5-turbo"},
        max_tokens = {type = "number", default = 4000, min = 100, max = 32000},
        temperature = {type = "number", default = 0.7, min = 0.0, max = 2.0},
        conversation_history_limit = {type = "number", default = 50, min = 1, max = 1000},
        auto_save_conversations = {type = "boolean", default = true}
    },

    -- File and path settings
    paths = {
        config_dir = {type = "string", required = true},
        data_dir = {type = "string", required = true},
        log_dir = {type = "string", required = true},
        backup_dir = {type = "string", required = false},
        temp_dir = {type = "string", default = "/tmp/codingbuddy"}
    },

    -- Performance and resource settings
    performance = {
        max_concurrent_requests = {type = "number", default = 5, min = 1, max = 20},
        request_timeout_seconds = {type = "number", default = 30, min = 5, max = 300},
        cache_enabled = {type = "boolean", default = true},
        cache_size_mb = {type = "number", default = 100, min = 10, max = 1000}
    }
}

-- Validation error types
local ValidationError = {
    MISSING_REQUIRED = "missing_required_field",
    INVALID_TYPE = "invalid_type",
    OUT_OF_RANGE = "value_out_of_range",
    INVALID_ENUM = "invalid_enum_value",
    PATTERN_MISMATCH = "pattern_mismatch",
    CUSTOM_VALIDATION = "custom_validation_failed"
}

-- Error collection for batch validation
local ValidationErrors = {}
ValidationErrors.__index = ValidationErrors

function ValidationErrors:new()
    local instance = {
        errors = {},
        warnings = {},
        count = 0
    }
    setmetatable(instance, self)
    return instance
end

function ValidationErrors:add_error(path, error_type, message, value)
    table.insert(self.errors, {
        path = path,
        type = error_type,
        message = message,
        value = value,
        severity = "error"
    })
    self.count = self.count + 1
end

function ValidationErrors:add_warning(path, message, value)
    table.insert(self.warnings, {
        path = path,
        message = message,
        value = value,
        severity = "warning"
    })
end

function ValidationErrors:has_errors()
    return #self.errors > 0
end

function ValidationErrors:get_summary()
    return {
        error_count = #self.errors,
        warning_count = #self.warnings,
        total_issues = #self.errors + #self.warnings
    }
end

-- Core validation functions
local function validate_type(value, expected_type)
    local actual_type = type(value)

    if expected_type == "number" and actual_type == "string" then
        local num = tonumber(value)
        return num ~= nil, num
    end

    return actual_type == expected_type, value
end

local function validate_range(value, min_val, max_val)
    if min_val and value < min_val then
        return false, string.format("Value %s is below minimum %s", tostring(value), tostring(min_val))
    end
    if max_val and value > max_val then
        return false, string.format("Value %s exceeds maximum %s", tostring(value), tostring(max_val))
    end
    return true
end

local function validate_enum(value, enum_values)
    for _, valid_value in ipairs(enum_values) do
        if value == valid_value then
            return true
        end
    end
    return false, string.format("Value '%s' not in allowed values: %s",
                               tostring(value), table.concat(enum_values, ", "))
end

local function validate_pattern(value, pattern)
    if type(value) ~= "string" then
        return false, "Pattern validation requires string value"
    end
    local match = string.match(value, pattern)
    return match ~= nil, match and "Pattern matched" or "Pattern did not match"
end

-- Main validation function for a single field
local function validate_field(value, schema, path, errors)
    local field_schema = schema

    -- Handle required fields
    if field_schema.required and (value == nil or value == "") then
        errors:add_error(path, ValidationError.MISSING_REQUIRED,
                        "Required field is missing", value)
        return nil
    end

    -- Use default if value is nil and default exists
    if value == nil and field_schema.default ~= nil then
        value = field_schema.default
    end

    -- Skip further validation if still nil
    if value == nil then
        return nil
    end

    -- Type validation
    local type_valid, converted_value = validate_type(value, field_schema.type)
    if not type_valid then
        errors:add_error(path, ValidationError.INVALID_TYPE,
                        string.format("Expected %s, got %s", field_schema.type, type(value)), value)
        return value  -- Return original value on type error
    end
    value = converted_value

    -- Range validation for numbers
    if field_schema.type == "number" and (field_schema.min or field_schema.max) then
        local range_valid, range_message = validate_range(value, field_schema.min, field_schema.max)
        if not range_valid then
            errors:add_error(path, ValidationError.OUT_OF_RANGE, range_message, value)
        end
    end

    -- Enum validation
    if field_schema.enum then
        local enum_valid, enum_message = validate_enum(value, field_schema.enum)
        if not enum_valid then
            errors:add_error(path, ValidationError.INVALID_ENUM, enum_message, value)
        end
    end

    -- Pattern validation for strings
    if field_schema.pattern and field_schema.type == "string" then
        local pattern_valid, pattern_message = validate_pattern(value, field_schema.pattern)
        if not pattern_valid then
            errors:add_error(path, ValidationError.PATTERN_MISMATCH, pattern_message, value)
        end
    end

    return value
end

-- Recursive validation for nested configuration objects
local function validate_config_section(config_section, schema_section, base_path, errors)
    local validated_section = {}

    -- Validate each field in the schema
    for field_name, field_schema in pairs(schema_section) do
        local field_path = base_path and (base_path .. "." .. field_name) or field_name
        local field_value = config_section and config_section[field_name] or nil

        local validated_value = validate_field(field_value, field_schema, field_path, errors)
        if validated_value ~= nil then
            validated_section[field_name] = validated_value
        end
    end

    -- Check for unknown fields in config
    if config_section then
        for field_name, field_value in pairs(config_section) do
            if not schema_section[field_name] then
                local field_path = base_path and (base_path .. "." .. field_name) or field_name
                errors:add_warning(field_path, "Unknown configuration field will be ignored", field_value)
            end
        end
    end

    return validated_section
end

-- Public API functions

--- Validates a complete configuration object against the schema
-- @param config table: The configuration object to validate
-- @param custom_schema table: Optional custom schema (uses default if nil)
-- @return table, ValidationErrors: Validated config and error collection
function config_validator.validate_config(config, custom_schema)
    local schema = custom_schema or CONFIG_SCHEMA
    local errors = ValidationErrors:new()
    local validated_config = {}

    if not config or type(config) ~= "table" then
        errors:add_error("root", ValidationError.INVALID_TYPE, "Configuration must be a table", config)
        return {}, errors
    end

    -- Validate each top-level section
    for section_name, section_schema in pairs(schema) do
        local section_config = config[section_name]
        validated_config[section_name] = validate_config_section(section_config, section_schema, section_name, errors)
    end

    return validated_config, errors
end

--- Creates a configuration object with all default values
-- @param custom_schema table: Optional custom schema
-- @return table: Configuration with default values
function config_validator.create_default_config(custom_schema)
    local schema = custom_schema or CONFIG_SCHEMA
    local default_config = {}

    for section_name, section_schema in pairs(schema) do
        default_config[section_name] = {}
        for field_name, field_schema in pairs(section_schema) do
            if field_schema.default ~= nil then
                default_config[section_name][field_name] = field_schema.default
            end
        end
    end

    return default_config
end

--- Validates a configuration file and returns validated config
-- @param file_path string: Path to configuration file
-- @return table, ValidationErrors: Validated config and errors
function config_validator.validate_config_file(file_path)
    if not utils.file_exists(file_path) then
        local errors = ValidationErrors:new()
        errors:add_error("file", ValidationError.MISSING_REQUIRED, "Configuration file not found", file_path)
        return {}, errors
    end

    local content, read_error = utils.safe_read_all(file_path)
    if not content then
        local errors = ValidationErrors:new()
        errors:add_error("file", ValidationError.CUSTOM_VALIDATION,
                        "Failed to read configuration file: " .. tostring(read_error), file_path)
        return {}, errors
    end

    -- Parse JSON (you'd need to implement or use a JSON library)
    local config = utils.simple_json_decode(content)  -- Assuming this exists
    if not config then
        local errors = ValidationErrors:new()
        errors:add_error("file", ValidationError.CUSTOM_VALIDATION,
                        "Invalid JSON in configuration file", file_path)
        return {}, errors
    end

    return config_validator.validate_config(config)
end

--- Exports the validation schema for external use
-- @return table: The configuration schema
function config_validator.get_schema()
    return CONFIG_SCHEMA
end

--- Exports validation error types
-- @return table: ValidationError enumeration
function config_validator.get_error_types()
    return ValidationError
end

return config_validator
