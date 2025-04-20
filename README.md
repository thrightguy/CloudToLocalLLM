CloudToLocalLLM

CloudToLocalLLM is a project that bridges the gap between cloud-based applications and local large language models (LLMs). It allows you to run a local LLM instance (using Ollama with the tinyllama model) and expose it to a cloud interface, making it accessible via a web browser. The project uses a combination of Docker containers, a Dart-based tunnel, and a Node.js-based cloud service to securely relay requests from the cloud to your local LLM.

Project Overview

The architecture consists of three main components, all managed with Docker Compose:
- Ollama Container: Runs the Ollama server with the tinyllama model, serving as the local LLM backend.
- Tunnel Container: A Dart-based service that acts as a relay between the local Ollama server and the cloud service.
- Cloud Container: A Node.js-based web server that provides a user-friendly web interface to interact with the LLM.

This setup allows you to leverage the power of a local LLM while accessing it remotely through a cloud-like interface, ensuring privacy and control over your LLM instance.

Features

- Local LLM Execution: Run the tinyllama model locally using Ollama, ensuring data privacy.
- Cloud Accessibility: Access your local LLM through a web interface hosted in a Docker container.
- Secure Tunneling: Use a Dart-based tunnel to securely relay requests between the cloud and local services.
- Dockerized Setup: Easily deploy and manage the entire stack with Docker Compose.
- Simple Web Interface: Interact with the LLM via a clean, browser-based UI.

Prerequisites

Before setting up the project, ensure you have the following installed on your system:
- Docker: To run the containerized services. Install Docker: https://docs.docker.com/get-docker/
- Docker Compose: To orchestrate the multi-container setup. Install Docker Compose: https://docs.docker.com/compose/install/
- Git: To clone the repository and manage version control. Install Git: https://git-scm.com/downloads

Setup Instructions

Follow these steps to set up and run the CloudToLocalLLM project on your local machine.

1. Clone the Repository

Clone the repository to your local machine:

git clone https://github.com/thrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM

2. Prepare the Environment

The project is designed to run in D:\Dev\CloudToLocalLLM on Windows. If you're using a different directory or operating system, update the paths in the setup.ps1 script accordingly.

3. Run the Setup Script

The project includes a PowerShell script (setup.ps1) to automate the setup process. This script will:
- Create necessary files (e.g., docker-compose.yml, Dart and Node.js code).
- Start the Ollama container and ensure the tinyllama model is installed.
- Launch the tunnel and cloud containers using Docker Compose.

Run the script:

.\setup.ps1

If you're on a Unix-like system (e.g., Linux or macOS), you can adapt the script to Bash or manually run the equivalent commands.

4. Monitor the Setup

The script will log the progress of the Ollama container setup, including the server startup and model installation. You'll see output similar to:

2025-04-19 21:30:00 - Starting Ollama container...
2025-04-19 21:30:00 - Monitoring Ollama setup progress...
2025-04-19 21:30:00 - Tailing Ollama setup logs (this may take a few minutes)...
2025-04-19 21:30:00 - Starting Ollama server...
2025-04-19 21:30:05 - Waiting for Ollama server to start...
2025-04-19 21:30:06 - Ollama server is running
2025-04-19 21:30:06 - Installing tinyllama model...
2025-04-19 21:30:31 - Verifying tinyllama model installation...
2025-04-19 21:30:36 - tinyllama model installed successfully
2025-04-19 21:30:36 - Ollama setup completed in 36 seconds

Once the setup is complete, the script will start the remaining services (tunnel and cloud containers).

5. Access the Web Interface

After the setup completes, you can access the web interface at:

http://localhost:3000

The interface allows you to select a model (default is tinyllama) and enter prompts to interact with the LLM.

Usage

1. Open the Web Interface:
    - Navigate to http://localhost:3000 in your browser.
    - You'll see a simple UI with a dropdown to select the model and a text box to enter your prompt.

2. Interact with the LLM:
    - Select tinyllama from the dropdown (other models like mistral are listed but may require additional setup).
    - Enter a prompt (e.g., "Hello, world!") and click "Send."
    - The response from the LLM will be displayed below the input field.

3. Stop the Services:
    - To stop the containers, run:
      docker-compose -f docker-compose.yml -p cloudtolocalllm_dev down

Project Structure

Here's an overview of the key files and directories in the repository:

- setup.ps1: PowerShell script to automate the setup of the project.
- git-push.ps1 / git-push.sh: Scripts to automate Git commits and pushes to the repository.
- docker-compose.yml: Docker Compose configuration for the Ollama, tunnel, and cloud containers.
- lib/main.dart: Dart code for the tunnel service, responsible for relaying requests between the cloud and Ollama.
- cloud/server.js: Node.js code for the cloud service, providing the web interface.
- logs/: Directory where setup logs (e.g., ollama_setup.log) are stored.
- setup_ollama.sh, setup_tunnel.sh, setup_cloud.sh: Bash scripts executed inside the containers to handle setup and validation.

Troubleshooting

- Ollama Server Not Starting:
    - Check the logs for the Ollama container:
      docker logs cloudtolocalllm_dev_ollama
    - Ensure your system has enough resources (CPU, memory) to run the containers.
    - Verify that port 11434 is not in use by another process.

- Web Interface Not Accessible:
    - Ensure the cloud container is running:
      docker ps
    - Check the logs for the cloud container:
      docker logs cloudtolocalllm_dev_cloud
    - Verify that port 3000 is not blocked by your firewall.

- Model Not Found:
    - If the tinyllama model fails to install, ensure you have an internet connection, as the model needs to be downloaded.
    - Check the Ollama setup logs in logs/ollama_setup.log.

Contributing

Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a new branch (git checkout -b feature/your-feature).
3. Make your changes and commit them (git commit -m "Add your feature").
4. Push to your branch (git push origin feature/your-feature).
5. Open a pull request on GitHub.

License

This project is licensed under the MIT License. See the LICENSE file for details.

Acknowledgments

- Ollama (https://ollama.com/) for providing an easy-to-use LLM server.
- Docker (https://www.docker.com/) for containerization.
- Dart (https://dart.dev/) and Node.js (https://nodejs.org/) for the tunnel and cloud services, respectively.

Happy coding! 🚀
