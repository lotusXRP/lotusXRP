https://github.com/lotusXRP/my-speed-insights-app.git#!/bin/bash

# --- Configuration (REQUIRED - YOU MUST FILL THESE IN) ---

# 1. Your GitHub username or organization name (e.g., lotusXRP)
GITHUB_USER="lotusXRP"

# 2. The name of your GitHub repository (e.g., my-speed-insights-app)
GITHUB_REPO_NAME="my-speed-insights-app"  # CHANGE THIS!

# 3. The name of your local project directory (usually the same as the repo name)
PROJECT_NAME="$GITHUB_REPO_NAME"

# 4. Choose whether to create a NEW Vercel project or use an EXISTING one.
#    Set to "new" or "existing" (lowercase).
VERCEL_PROJECT_ACTION="new"  # CHANGE THIS! (or leave as "new")

# 5. (Only if VERCEL_PROJECT_ACTION is "existing") The ID or name of your EXISTING Vercel project.
#    You can find the Project ID in your Vercel project settings.
VERCEL_PROJECT_ID=""  # CHANGE THIS if VERCEL_PROJECT_ACTION is "existing"

# --- Derived Variables (Do not modify) ---
GITHUB_REPO_URL="git@github.com:$GITHUB_USER/$GITHUB_REPO_NAME.git"

# --- Functions for Error Handling ---

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# --- Input Validation ---

if [[ -z "$GITHUB_USER" || -z "$GITHUB_REPO_NAME" ]]; then
    error_exit "You MUST set GITHUB_USER and GITHUB_REPO_NAME in the script."
fi

if [[ "$VERCEL_PROJECT_ACTION" != "new" && "$VERCEL_PROJECT_ACTION" != "existing" ]]; then
    error_exit "VERCEL_PROJECT_ACTION must be set to either 'new' or 'existing'."
fi

if [[ "$VERCEL_PROJECT_ACTION" == "existing" && -z "$VERCEL_PROJECT_ID" ]]; then
    error_exit "If VERCEL_PROJECT_ACTION is 'existing', you MUST set VERCEL_PROJECT_ID."
fi

# Check if the project directory already exists
if [ -d "$PROJECT_NAME" ]; then
  error_exit "The project directory '$PROJECT_NAME' already exists.  Please choose a different name or delete the existing directory."
fi

# --- Step 0: Install Prerequisites (Assumes Debian/Ubuntu - Adapt if needed) ---

echo "Updating package lists..."
sudo apt update || error_exit "Failed to update package lists."

echo "Installing Git..."
sudo apt install -y git || error_exit "Failed to install Git."

echo "Installing Node.js and npm (using nvm)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash || error_exit "Failed to install nvm."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install 18 || error_exit "Failed to install Node.js v18."
nvm use 18 || error_exit "Failed to use Node.js v18"

echo "Installing Vercel CLI..."
npm install -g vercel || error_exit "Failed to install Vercel CLI."

# --- Step 1: Create React App ---

echo "Creating React app..."
npx create-react-app "$PROJECT_NAME" || error_exit "Failed to create React app."
cd "$PROJECT_NAME" || error_exit "Failed to change directory to $PROJECT_NAME"

# --- Step 2: Install Dependencies ---

echo "Installing dependencies..."
npm install react-router-dom @vercel/speed-insights || error_exit "Failed to install dependencies."

# --- Step 3: Create Project Structure ---

echo "Creating project structure..."
mkdir -p src/components src/pages || error_exit "Failed to create directories."

# --- Step 4: Create Components ---

# Navigation.js
cat > src/components/Navigation.js <<EOF
import React from 'react';
import { Link } from 'react-router-dom';
import './Navigation.css';

function Navigation() {
  return (
    <nav className="navbar">
      <ul>
        <li><Link to="/">Home</Link></li>
        <li><Link to="/about">About</Link></li>
        <li><Link to="/contact">Contact</Link></li>
      </ul>
    </nav>
  );
}

export default Navigation;
EOF

# Navigation.css
cat > src/components/Navigation.css <<EOF
.navbar {
  background-color: #333;
  color: white;
  padding: 1rem;
}
ul {
  list-style: none;
  padding: 0;
  display: flex;
  gap: 1rem;
}
a {
  color: white;
  text-decoration: none;
}
a:hover {
  text-decoration: underline;
}
EOF

# HomePage.js
cat > src/pages/HomePage.js <<EOF
import React from 'react';

function HomePage() {
  return (
    <div>
      <h1>Welcome to the Home Page</h1>
      <p>This is a demo for Vercel Speed Insights.</p>
    </div>
  );
}
export default HomePage;
EOF

# AboutPage.js
cat > src/pages/AboutPage.js <<EOF
import React from 'react';
function AboutPage() {
  return (
    <div><h1>About Us</h1><p>Learn more about our company.</p></div>
  );
}
export default AboutPage;
EOF

# ContactPage.js
cat > src/pages/ContactPage.js <<EOF
import React from 'react';
function ContactPage() {
  return (
    <div><h1>Contact Us</h1><p>Get in touch!</p></div>
  );
}
export default ContactPage;
EOF

# --- Step 5: Modify App.js ---
cat > src/App.js <<EOF
import React, { useEffect } from 'react';
import { BrowserRouter as Router, Route, Routes, useLocation } from 'react-router-dom';
import { SpeedInsights } from '@vercel/speed-insights/react';
import { rumUpdate } from '@vercel/speed-insights';
import Navigation from './components/Navigation';
import HomePage from './pages/HomePage';
import AboutPage from './pages/AboutPage';
import ContactPage from './pages/ContactPage';

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

function AppContent() {
    const location = useLocation();

    useEffect(() => {
        rumUpdate();
    }, [location]);

  return (
    <>
      <Navigation />
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/about" element={<AboutPage />} />
        <Route path="/contact" element={<ContactPage />} />
      </Routes>
      <SpeedInsights />
    </>
  );
}

export default App;

EOF

# --- Step 6: Create .gitignore ---
cat > .gitignore <<EOF
node_modules/
build/
.env
.DS_Store
EOF

# --- Step 7: Initialize Git and Push to GitHub ---

echo "Initializing Git and pushing to GitHub..."
git init || error_exit "Failed to initialize Git."
git add . || error_exit "Failed to add files to Git."
git commit -m "Initial commit" || error_exit "Failed to commit changes."
git remote add origin "$GITHUB_REPO_URL" || error_exit "Failed to add remote origin: $GITHUB_REPO_URL"
git branch -M main || error_exit "Failed to rename branch to main."
git push -u origin main || error_exit "Failed to push to GitHub."

# --- Step 8: Link to Vercel and Deploy ---

echo "Linking to Vercel..."
if [[ "$VERCEL_PROJECT_ACTION" == "new" ]]; then
    # Create a new Vercel project
    vercel link --yes || error_exit "Failed to link to a new Vercel project."
else
    # Link to an existing Vercel project
    vercel link --yes --project "$VERCEL_PROJECT_ID" || error_exit "Failed to link to existing Vercel project: $VERCEL_PROJECT_ID"
fi

echo "Deploying to Vercel..."
vercel --prod --confirm || error_exit "Failed to deploy to Vercel."

echo "Deployment complete!  Check your Vercel dashboard for the URL."