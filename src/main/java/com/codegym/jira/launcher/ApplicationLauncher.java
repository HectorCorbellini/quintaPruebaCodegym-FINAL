package com.codegym.jira.launcher;

import com.codegym.jira.CodegymJiraApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Scanner;
import java.util.concurrent.TimeUnit;

/**
 * Java-based launcher for the CodeGym Jira application.
 * Replaces shell scripts with pure Java implementation.
 */
public class ApplicationLauncher {

    private static final String POSTGRES_CONTAINER_NAME = "postgres-db";
    private static final int MAX_DOCKER_START_ATTEMPTS = 10;
    private static final int DOCKER_START_WAIT_SECONDS = 2;

    public static void main(String[] args) {
        try {
            System.out.println("Starting CodeGym Jira Application Launcher...");
            
            // Check and start Docker if needed
            ensureDockerIsRunning();
            
            // Clean up existing containers
            cleanupExistingContainers();
            
            // Kill processes using ports 5432 and 5433
            killProcessesUsingPorts(5432, 5433);
            
            // Start PostgreSQL container
            startPostgresContainer();
            
            // Select profile (dev or prod)
            String profile = selectProfile();
            
            // Configure database connection for development mode
            if ("dev".equals(profile)) {
                configureDevDatabase();
            }
            
            // Start the Spring Boot application
            System.out.println("Starting Spring Boot application with profile: " + profile);
            
            // Run the application and capture the context
            // We don't close the context as it's needed for the application to run
            // This is a deliberate choice, not a resource leak
            @SuppressWarnings("PMD.CloseResource")
            ConfigurableApplicationContext context = new SpringApplicationBuilder(CodegymJiraApplication.class)
                .profiles(profile)
                .run(args);
            
            // Display access information after successful startup
            if (context.isRunning()) {
                System.out.println("\n===========================================================");
                System.out.println("APPLICATION STARTED SUCCESSFULLY");
                System.out.println("===========================================================");
                System.out.println("\nThe main application URL is:\n");
                System.out.println("http://localhost:8080");
                System.out.println("\nYou can also access specific Actuator endpoints:\n");
                System.out.println("Health check: http://localhost:8080/actuator/health");
                System.out.println("Metrics: http://localhost:8080/actuator/metrics");
                System.out.println("Info: http://localhost:8080/actuator/info");
                System.out.println("\n===========================================================");
            }
            
        } catch (Exception e) {
            System.err.println("Error starting application: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    private static boolean isDockerRunning() {
        try {
            Process process = Runtime.getRuntime().exec("docker info");
            int exitCode = process.waitFor();
            return exitCode == 0;
        } catch (Exception e) {
            return false;
        }
    }
    
    private static void ensureDockerIsRunning() throws Exception {
        System.out.println("Checking if Docker daemon is running...");
        
        if (!isDockerRunning()) {
            System.out.println("Docker daemon is not running. Attempting to start it...");
            
            // Try different methods to start Docker
            String[] startCommands = {
                "service docker start",
                "systemctl start docker",
                "/etc/init.d/docker start"
            };
            
            // Suppress DataflowAnomalyAnalysis as we're using the variable correctly
            @SuppressWarnings("PMD.DataflowAnomalyAnalysis")
            boolean dockerStarted = false;
            for (String command : startCommands) {
                try {
                    Process process = Runtime.getRuntime().exec(command);
                    int exitCode = process.waitFor();
                    if (exitCode == 0) {
                        System.out.println("Docker started successfully with: " + command);
                        dockerStarted = true;
                        break;
                    }
                } catch (Exception e) {
                    // Try next command if this one fails
                    System.out.println("Command '" + command + "' failed: " + e.getMessage());
                }
            }
            
            if (!dockerStarted) {
                throw new Exception("Failed to start Docker daemon. Please start it manually.");
            }
            
            // Wait for Docker to be fully available
            System.out.println("Waiting for Docker to become available...");
            for (int i = 0; i < MAX_DOCKER_START_ATTEMPTS; i++) {
                if (isDockerRunning()) {
                    System.out.println("Docker is now available.");
                    break;
                }
                
                if (i == MAX_DOCKER_START_ATTEMPTS - 1) {
                    throw new Exception("Docker did not become available after waiting. Please check Docker installation.");
                }
                
                System.out.println("Waiting... (" + (i + 1) + "/" + MAX_DOCKER_START_ATTEMPTS + ")");
                TimeUnit.SECONDS.sleep(DOCKER_START_WAIT_SECONDS);
            }
        } else {
            System.out.println("Docker daemon is already running.");
        }
    }
    
    private static void cleanupExistingContainers() throws Exception {
        System.out.println("Cleaning up existing containers...");
        
        // Remove postgres-db container if it exists
        executeCommand("docker rm -f " + POSTGRES_CONTAINER_NAME);
        
        // Remove postgres-db-test container if it exists
        executeCommand("docker rm -f postgres-db-test");
    }
    
    private static void killProcessesUsingPorts(int... ports) throws Exception {
        for (int port : ports) {
            System.out.println("Checking for processes using port " + port + "...");
            
            // Find PID using the port
            // Suppress DataflowAnomalyAnalysis as we're using the process correctly
            @SuppressWarnings("PMD.DataflowAnomalyAnalysis")
            Process findProcess = Runtime.getRuntime().exec("lsof -t -i:" + port);
            
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(findProcess.getInputStream()))) {
                String pid = reader.readLine();
                
                if (pid != null && !pid.isEmpty()) {
                    System.out.println("Killing process " + pid + " that is using port " + port + "...");
                    executeCommand("kill -9 " + pid);
                    TimeUnit.SECONDS.sleep(2);
                }
            }
        }
    }
    
    private static void startPostgresContainer() throws Exception {
        System.out.println("Starting PostgreSQL container...");
        
        // Get the selected profile to determine which password to use
        String profile = selectProfile();
        String dbPassword = "dev".equals(profile) ? "JiraRush" : "CodeGymJira";
        
        String dockerCommand = "docker run --name " + POSTGRES_CONTAINER_NAME + " " +
                "-e POSTGRES_USER=jira " +
                "-e POSTGRES_PASSWORD=" + dbPassword + " " +
                "-e POSTGRES_DB=jira " +
                "-e PGDATA=/var/lib/postgresql/data/pgdata " +
                "-v " + System.getProperty("user.dir") + "/pgdata:/var/lib/postgresql/data " +
                "--network host " +
                "-d " +
                "postgres:13";
        
        Process process = Runtime.getRuntime().exec(dockerCommand);
        int exitCode = process.waitFor();
        
        if (exitCode != 0) {
            throw new Exception("Failed to start PostgreSQL container.");
        }
        
        // Wait for PostgreSQL to be ready
        System.out.println("Waiting for PostgreSQL to be ready...");
        TimeUnit.SECONDS.sleep(5);
        
        // Check if PostgreSQL is accepting connections
        System.out.println("Verifying PostgreSQL connection...");
        Process checkProcess = Runtime.getRuntime().exec("docker exec " + POSTGRES_CONTAINER_NAME + " pg_isready -U jira");
        exitCode = checkProcess.waitFor();
        
        if (exitCode != 0) {
            System.out.println("PostgreSQL is not ready yet. Waiting 10 more seconds...");
            TimeUnit.SECONDS.sleep(10);
            
            checkProcess = Runtime.getRuntime().exec("docker exec " + POSTGRES_CONTAINER_NAME + " pg_isready -U jira");
            exitCode = checkProcess.waitFor();
            
            if (exitCode != 0) {
                throw new Exception("PostgreSQL container failed to start properly.");
            }
        }
        
        System.out.println("PostgreSQL is ready.");
    }
    
    private static String selectedProfile = null;
    
    private static String selectProfile() {
        if (selectedProfile != null) {
            return selectedProfile;
        }
        
        System.out.println("\nSelect execution mode:");
        System.out.println("1) Production mode");
        System.out.println("2) Development mode (default)");
        
        try (Scanner scanner = new Scanner(System.in)) {
            System.out.print("\nEnter your option (1 or 2): ");
            String input = scanner.nextLine().trim();
            
            selectedProfile = "".equals(input) || "2".equals(input) ? "dev" : "prod";
            return selectedProfile;
        }
    }
    
    private static void configureDevDatabase() throws Exception {
        System.out.println("Configuring environment for development mode...");
        
        // Create backup of original application-dev.yaml
        Path originalPath = Paths.get(System.getProperty("user.dir"), "src/main/resources/application-dev.yaml");
        Path backupPath = Paths.get(System.getProperty("user.dir"), "src/main/resources/application-dev.yaml.bak");
        
        Files.copy(originalPath, backupPath, StandardCopyOption.REPLACE_EXISTING);
        
        // Read the content of the file
        String content = new String(Files.readAllBytes(originalPath));
        
        // Replace the database URL
        content = content.replace(
                "jdbc:postgresql://localhost:5433/jira-test", 
                "jdbc:postgresql://localhost:5432/jira");
        
        // Ensure the password is set to JiraRush
        if (!content.contains("password: JiraRush")) {
            content = content.replaceAll("password:.*", "password: JiraRush");
        }
        
        // Write the modified content back to the file
        Files.write(originalPath, content.getBytes());
        
        System.out.println("Development database configuration updated with password: JiraRush");
        
        // Register shutdown hook to restore original file
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                if (Files.exists(backupPath)) {
                    Files.move(backupPath, originalPath, StandardCopyOption.REPLACE_EXISTING);
                    System.out.println("Restored original application-dev.yaml file.");
                }
            } catch (Exception e) {
                System.err.println("Error restoring application-dev.yaml: " + e.getMessage());
            }
        }));
    }
    
    private static void executeCommand(String command) throws Exception {
        Process process = Runtime.getRuntime().exec(command);
        process.waitFor();
    }
}
