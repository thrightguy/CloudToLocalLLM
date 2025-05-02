# Deploying CloudToLocalLLM Cloud Component on Render

This guide provides step-by-step instructions for deploying the CloudToLocalLLM cloud component on [Render](https://render.com), a modern cloud platform.

## Prerequisites

Before you begin, make sure you have:

1. A [Render account](https://dashboard.render.com/register) (you can sign up for free)
2. A [GitHub account](https://github.com/join) to fork or clone the repository
3. An [Auth0 account](https://auth0.com/signup) for authentication (free tier available)

## Step 1: Set Up Auth0

1. **Create a new Auth0 Application**:
   - Log in to your Auth0 dashboard
   - Go to "Applications" > "Create Application"
   - Name it "CloudToLocalLLM"
   - Select "Regular Web Applications"
   - Click "Create"

2. **Configure Auth0 Application Settings**:
   - In the application settings, find the "Allowed Callback URLs" field
   - For development: `http://localhost:3000/callback`
   - For production: `https://your-render-app-name.onrender.com/callback`
   - Save changes

3. **Note Your Auth0 Credentials**:
   - Domain (e.g., `your-tenant.auth0.com`)
   - Client ID
   - Client Secret
   
   You'll need these values when configuring your Render service.

## Step 2: Fork or Clone the Repository

1. Fork the CloudToLocalLLM repository to your GitHub account, or clone it and push to a new repository.
2. Make sure the repository includes the `webapp` directory with all necessary files.

## Step 3: Deploy to Render

### Option 1: Deploy Using Render Blueprint (Recommended)

1. **Connect Your Repository to Render**:
   - Go to the Render Dashboard
   - Click "New" > "Blueprint"
   - Connect your GitHub account if you haven't already
   - Select the repository containing CloudToLocalLLM
   - Click "Apply Blueprint"

2. **Configure Environment Variables**:
   - Render will detect the `render.yaml` file and create the service
   - Click on the created web service
   - Go to "Environment" tab
   - Add the following environment variables:
     - `SESSION_SECRET`: Generate a random string (e.g., using `openssl rand -hex 32`)
     - `JWT_SECRET`: Generate a random string (e.g., using `openssl rand -hex 32`)
     - `AUTH0_DOMAIN`: Your Auth0 domain (e.g., `your-tenant.auth0.com`)
     - `AUTH0_CLIENT_ID`: Your Auth0 client ID
     - `AUTH0_CLIENT_SECRET`: Your Auth0 client secret
     - `AUTH0_CALLBACK_URL`: `https://your-render-app-name.onrender.com/callback`
   - Click "Save Changes"

3. **Deploy the Service**:
   - Go to "Manual Deploy" tab
   - Click "Deploy latest commit"
   - Wait for the deployment to complete

### Option 2: Deploy Manually

1. **Create a New Web Service**:
   - Go to the Render Dashboard
   - Click "New" > "Web Service"
   - Connect your GitHub account if you haven't already
   - Select the repository containing CloudToLocalLLM
   - Click "Continue"

2. **Configure the Web Service**:
   - Name: `cloudtolocalllm-cloud` (or your preferred name)
   - Environment: `Node`
   - Region: Choose the region closest to your users
   - Branch: `main` (or your default branch)
   - Root Directory: `webapp`
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Plan: Free (or choose a paid plan for production)
   - Click "Create Web Service"

3. **Configure Environment Variables**:
   - After the service is created, go to "Environment" tab
   - Add the following environment variables:
     - `NODE_ENV`: `production`
     - `SESSION_SECRET`: Generate a random string (e.g., using `openssl rand -hex 32`)
     - `JWT_SECRET`: Generate a random string (e.g., using `openssl rand -hex 32`)
     - `AUTH0_DOMAIN`: Your Auth0 domain (e.g., `your-tenant.auth0.com`)
     - `AUTH0_CLIENT_ID`: Your Auth0 client ID
     - `AUTH0_CLIENT_SECRET`: Your Auth0 client secret
     - `AUTH0_CALLBACK_URL`: `https://your-render-app-name.onrender.com/callback`
   - Click "Save Changes"

4. **Deploy the Service**:
   - Go to "Manual Deploy" tab
   - Click "Deploy latest commit"
   - Wait for the deployment to complete

## Step 4: Verify the Deployment

1. **Check the Deployment Status**:
   - Wait for the deployment to complete (status will change to "Live")
   - Click on the service URL (e.g., `https://your-render-app-name.onrender.com`)
   - You should see the CloudToLocalLLM cloud component running

2. **Test Authentication**:
   - Navigate to `https://your-render-app-name.onrender.com/login`
   - You should be redirected to Auth0 for authentication
   - After successful authentication, you should see the success page with a token

## Step 5: Configure the Windows Application

1. **Update the CloudToLocalLLM Windows App**:
   - Open the app settings
   - Enable cloud connectivity
   - Enter your Render service URL when prompted
   - Follow the authentication flow

2. **Verify Connection**:
   - Check the tunnel status in the app settings
   - It should show "Connected" if everything is set up correctly

## Troubleshooting

### Common Issues

1. **Deployment Fails**:
   - Check the build logs for errors
   - Ensure all dependencies are correctly specified in package.json
   - Verify that the start command is correct

2. **Authentication Fails**:
   - Check that Auth0 is correctly configured
   - Verify that the callback URL matches your Render service URL
   - Check environment variables for typos

3. **Connection Issues**:
   - Ensure the Windows app is using the correct cloud URL
   - Check that the tunnel service is running
   - Verify network connectivity

### Logs and Debugging

- Access logs from the Render dashboard by clicking on your service and selecting the "Logs" tab
- Enable more verbose logging by setting `DEBUG=*` in your environment variables

## Upgrading and Maintenance

### Updating the Application

1. Push changes to your GitHub repository
2. Render will automatically deploy the new version (if auto-deploy is enabled)
3. Alternatively, manually deploy from the Render dashboard

### Scaling

If you need more resources:

1. Go to your service in the Render dashboard
2. Click "Change Plan"
3. Select a plan with more resources
4. Confirm the change

## Security Considerations

- Always use strong, unique values for `SESSION_SECRET` and `JWT_SECRET`
- Keep your Auth0 credentials secure
- Consider enabling additional security features in Auth0 (MFA, etc.)
- For production use, consider upgrading to a paid Render plan with SLAs

## Additional Resources

- [Render Documentation](https://render.com/docs)
- [Auth0 Documentation](https://auth0.com/docs)
- [Node.js on Render](https://render.com/docs/deploy-node-express-app)