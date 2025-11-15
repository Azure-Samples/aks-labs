#!/usr/bin/env bash
# shfmt -i 2 -ci -w
set -e

# Requirements:
# - Java 17 or 21
# - Maven 3.8+
# - Docker Desktop
# - kubectl

################################################################################
FORK_URL=${1:-"https://github.com/spring-projects/spring-petclinic"}
PETCLINIC_DIR="spring-petclinic"
POSTGRES_CONTAINER="petclinic-postgres"
APP_PORT=8080
################################################################################

usage() {
  echo "usage: ${0##*/} [FORK_URL]"
  echo ""
  echo "Spring Boot PetClinic Workshop - Quick Start Script"
  echo "Sets up the entire workshop environment"
  echo ""
  echo "Examples:"
  echo "  ${0##*/}"
  echo "  ${0##*/} https://github.com/YOUR_USERNAME/spring-petclinic"
  exit 1
}

checkDependencies() {
  # check if the dependencies are installed
  local _NEEDED="java mvn docker kubectl"
  local _DEP_FLAG="false"

  echo -e "Checking dependencies ...\n"
  for i in ${_NEEDED}; do
    if hash "$i" 2>/dev/null; then
      # do nothing
      :
    else
      echo -e "\t $i not installed"
      _DEP_FLAG=true
    fi
  done

  if [[ "${_DEP_FLAG}" == "true" ]]; then
    echo -e "\nDependencies missing. Please fix that before proceeding"
    exit 1
  fi
}

printHeader() {
  echo "Spring Boot PetClinic Migration Workshop - Quick Start"
  echo "========================================================"
  echo "Using repository: ${FORK_URL}"
  echo ""
}

clonePetclinicRepo() {
  echo "Cloning Spring Boot PetClinic repository..."

  if [ -d "spring-petclinic" ]; then
    echo "spring-petclinic directory already exists. Removing..."
    rm -rf "spring-petclinic"
  fi

  git clone "${FORK_URL}" spring-petclinic
  echo "Repository cloned successfully to ./spring-petclinic!"
  echo ""
}

createSymlink() {
  echo "Creating symlink in workshop directory..."
  cd "${OLDPWD}"
  
  if [ -L "src" ]; then
    echo "Removing existing symlink..."
    rm "src"
  elif [ -d "src" ]; then
    echo "Removing existing src directory..."
    rm -rf "src"
  fi
  
  ln -s ~/spring-petclinic src
  echo "Symlink created: src -> ~/spring-petclinic"
  echo ""
}

setupPostgresql() {
  echo "Starting PostgreSQL container..."
  
  if docker ps -a --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
    echo "PostgreSQL container already exists. Checking if it's running..."
    if docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
      echo "PostgreSQL container is already running!"
    else
      echo "Starting existing PostgreSQL container..."
      docker start "${POSTGRES_CONTAINER}"
      echo "Waiting for PostgreSQL to be ready..."
      sleep 10
      echo "PostgreSQL container is now running!"
    fi
  else
    echo "Creating new PostgreSQL container..."
    docker run --name "${POSTGRES_CONTAINER}" \
      -e POSTGRES_DB=petclinic \
      -e POSTGRES_USER=petclinic \
      -e POSTGRES_PASSWORD=petclinic \
      -p 5432:5432 \
      -d postgres:15
    
    echo "Waiting for PostgreSQL to be ready..."
    sleep 15
    echo "PostgreSQL container is running!"
  fi
  echo ""
}

configureDatabase() {
  echo "Configuring local database connection..."
  cat > src/main/resources/application.properties <<'EOF'
spring.datasource.url=jdbc:postgresql://localhost:5432/petclinic
spring.datasource.username=petclinic
spring.datasource.password=petclinic
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.show-sql=true
EOF
  echo "Local database configuration updated!"
  echo ""
}

testLocalApplication() {
  echo "Testing local application..."
  echo "Building application..."
  mvn clean compile
  echo "Build successful!"

  echo "Starting application (this will run in background)..."
  nohup mvn spring-boot:run \
    -Dspring-boot.run.arguments="--spring.messages.basename=messages/messages --spring.datasource.url=jdbc:postgresql://localhost/petclinic --spring.sql.init.mode=always --spring.sql.init.schema-locations=classpath:db/postgres/schema.sql --spring.sql.init.data-locations=classpath:db/postgres/data.sql --spring.jpa.hibernate.ddl-auto=none" \
    > ../app.log 2>&1 < /dev/null &
  APP_PID=$!

  echo "Waiting for Spring Boot application to start (this may take 30-60 seconds)..."
  echo "The application is initializing the database and loading Spring components..."

  # Wait with progress indicators
  for i in {1..10}; do
    echo "  Checking startup progress... ($((i * 5)) seconds elapsed)"
    sleep 5
    
    # Check if app is ready after 15 seconds
    if [ $i -ge 3 ] && curl -s "http://localhost:${APP_PORT}" >/dev/null 2>&1; then
      echo "Application started successfully!"
      break
    fi
  done

  # Final verification
  if curl -s "http://localhost:${APP_PORT}" >/dev/null 2>&1; then
    echo "Application is running successfully at http://localhost:${APP_PORT}"
    echo "   You can now access the PetClinic web interface in your browser"
  else
    echo "Application failed to start after waiting. Checking logs..."
    echo "   Last few lines from app.log:"
    tail -10 ../app.log 2>/dev/null || echo "   No log file found"
    kill $APP_PID 2>/dev/null || true
    exit 1
  fi
}

reinitializeGit() {
  echo "Reinitializing git repository..."
  rm -rf .git
  git init
  git config --global user.name "Your Name"
  git config --global user.email "your_email@example.com"
}

printCompletionMessage() {
  echo ""
  echo "Workshop environment setup completed!"
  echo ""
  echo "Next Steps:"
  echo "   1. Your local PetClinic app is running at http://localhost:${APP_PORT}"
  echo "   2. Open the project in VS Code: code ~/spring-petclinic/"
  echo "   3. Use GitHub Copilot App Modernization to upgrade the codebase"
  echo "   4. Use Containerization Assist to generate Docker and K8s manifests"
  echo "   5. Deploy to AKS and test the modernized application"
  echo ""
  echo "Note: You're working with your cloned repository at: ${FORK_URL}"
  echo "   Your code is located at: ${PETCLINIC_DIR}/"
  echo "   A symlink is available at: src/ (points to ${PETCLINIC_DIR}/)"
  echo "   Any changes you make can be committed and pushed to your fork."
  echo ""
  echo "To clean up local resources:"
  echo "   # Stop and remove PostgreSQL container:"
  echo "   docker stop ${POSTGRES_CONTAINER} && docker rm ${POSTGRES_CONTAINER}"
  echo "   # Stop the Spring Boot application:"
  echo "   kill \$APP_PID"
  echo "   # Remove the symlink:"
  echo "   rm src"
  echo "   # Or stop all containers:"
  echo "   docker stop \$(docker ps -q)"
  echo ""
  echo "Let's get to modernizing!"
}

main() {
  # show usage if help is requested
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
  fi

  printHeader
  checkDependencies
  clonePetclinicRepo
  #createSymlink

  # Change into the petclinic directory for subsequent operations
  echo "Changing into the petclinic directory"
  cd "${PETCLINIC_DIR}"
  echo "Current directory: $(pwd)"
 
  # locking out repo this specific commit so it works with Java 17-21 
  #git reset --hard 7deaa78575fa9f967256302cc6a5e2487bb31162
  git reset --hard b26f235250627a235a2974a22f2317dbef27338d
  
  setupPostgresql
  configureDatabase
  testLocalApplication
  reinitializeGit
  printCompletionMessage
}

# entry point
main "$@"

exit 0