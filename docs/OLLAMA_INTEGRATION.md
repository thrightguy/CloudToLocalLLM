# Ollama Integration Guide

## Installing Ollama

To use Ollama with CloudToLocalLLM, you first need to have Ollama installed and running on your system.

- **Desktop Users (Windows, macOS, Linux):** The recommended way to install Ollama is by downloading the official desktop application from the [Ollama website](https://ollama.com/). This provides a user-friendly interface for managing models and running the Ollama server.
- **Linux (Server/Advanced Users):** You can also install Ollama using the command-line instructions provided on their website, typically involving a `curl` script.
- **Docker:** Ollama can be run as a Docker container. Refer to the [Ollama Docker Hub page](https://hub.docker.com/r/ollama/ollama) for instructions.

Once Ollama is installed and running, CloudToLocalLLM should be able to connect to it (by default at `http://localhost:11434`).

## Overview

This guide provides information about the CloudToLocalLLM integration with Ollama, including hardware detection, model recommendations, and model naming conventions.

## Hardware Detection

CloudToLocalLLM includes a sophisticated hardware detection system that analyzes the user's available hardware resources and recommends appropriate models based on those resources.

### Hardware Detection Process

The application detects:

- Available System RAM (in MB)
- GPU presence
- GPU name
- VRAM amount (if GPU is present)

The detection process works differently depending on the platform:

- **Windows**: Uses WMI commands to detect RAM and GPU specifications
- **Linux**: Uses `free` and `lspci` commands
- **macOS**: Uses `sysctl` and `system_profiler` commands

### Memory Thresholds

Models are recommended based on the following memory thresholds:

| Memory Available | Recommended Models                                     |
|------------------|--------------------------------------------------------|
| <2GB             | tinyllama, phi3:mini                                   |
| 2GB+             | llama3:8b, phi3:small, gemma:2b                       |
| 4GB+             | llama3:70b-q4_0 (quantized), gemma:7b, mistral:v1     |
| 8GB+             | llama3:8b-instruct, mistral:small3.1, gemma3:8b-instruct |
| 16GB+            | llama3:70b-instruct-q4_1, llama3:70b, mixtral:8x7b    |
| 32GB+            | llama3:70b-instruct, gemma3:27b-instruct             |

## Model Naming Conventions

Ollama uses a specific naming convention for models:

```
model_family[:version][size][-variant]
```

### Common Model Families

- **llama3**: Meta's Llama 3 models
- **gemma3**: Google's Gemma 3 models
- **phi3**: Microsoft's Phi-3 models
- **mistral**: Mistral AI's models
- **mixtral**: Mixture of experts models from Mistral AI

### Variants

- **instruct**: Fine-tuned for instruction following
- **chat**: Optimized for conversational use
- **vision**: Models with image understanding capabilities

### Quantization

- **q4_0**: 4-bit quantization (basic)
- **q4_1**: 4-bit quantization (improved)
- **q5_0**: 5-bit quantization
- **q5_1**: 5-bit quantization (improved)
- **q8_0**: 8-bit quantization

### Example Models

- `llama3:8b-instruct`: Llama 3 8B instruction-following model
- `gemma3:27b-instruct`: Gemma 3 27B instruction-following model
- `phi3:mini`: Phi-3 mini model
- `mixtral:8x7b`: Mixtral 8x7B base model
- `llama3:70b-q4_0`: Llama 3 70B with 4-bit quantization

## Automatic Model Selection

CloudToLocalLLM can automatically select the most appropriate model based on the user's hardware capabilities using the `pullRecommendedModel()` method:

1. The app detects hardware specifications
2. It generates a list of recommended models
3. It prioritizes instruction-tuned models (containing "instruct" in the name)
4. It selects a balanced model that matches hardware capabilities

## Premium vs. Free Features

During the testing phase, all premium features are available for free (controlled by the `freePremiumFeaturesDuringTesting` flag in AppConfig).

### Future Premium Features:

- API-based services like OpenAI and Anthropic integration
- Advanced model management
- Cloud synchronization
- Remote access

## Model Management

The application provides the following model management capabilities:

### For Local Models (Ollama)

- List available models
- Pull (download) new models
- Delete existing models
- Get model information (size, description)
- Track last used time

### API Endpoints

The application communicates with Ollama using the following API endpoints:

- GET `/api/tags`: List available models
- POST `/api/pull`: Download a new model
- DELETE `/api/delete`: Remove a model
- POST `/api/generate`: Generate text with a model

## Best Practices

1. **Resource Considerations**:
   - Always check available memory before recommending large models
   - Prefer quantized models for limited-memory environments
   - Offer smaller models as alternatives

2. **Model Selection**:
   - Prioritize instruction-tuned models for chat applications
   - For most users, 8B parameter models offer a good balance of quality and performance
   - Recommend quantized versions of larger models when VRAM is limited

3. **User Experience**:
   - Display download progress when pulling models
   - Provide estimated size information before downloading
   - Cache model information to avoid repeated API calls 