#!/usr/bin/env lua

-- Test script for Ollama integration
-- Run with: lua test_ollama.lua

package.path = package.path .. ";./codingbuddy/?.lua"

local ai_connector = require('ai_connector')

print("Testing Ollama integration...")

-- Test 1: Check if Ollama provider is configured
local test_opts = {
  prompt = "Hello, can you respond with 'Ollama is working!' ?",
  provider = "ollama",
  model = "llama3.1"
}

print("Test 1: Direct Ollama call")
print("Options:", require('codingbuddy.json').encode(test_opts))

local response, err = ai_connector.chat(test_opts)

if response then
  print("SUCCESS: " .. tostring(response))
else
  print("FAILED: " .. tostring(err))
end

print("\nTest 2: Fallback chain with Ollama")
local test_opts2 = {
  prompt = "Test fallback",
  -- Let it use fallback chain which should include ollama
}

local response2, err2 = ai_connector.chat(test_opts2)

if response2 then
  print("SUCCESS: Fallback worked")
else
  print("FAILED: " .. tostring(err2))
end

print("\nOllama integration test complete.")
print("Note: These tests will only succeed if:")
print("1. Ollama is installed and running (ollama serve)")
print("2. A model like llama3.1 is downloaded (ollama pull llama3.1)")
print("3. The Ollama service is accessible at localhost:11434")
