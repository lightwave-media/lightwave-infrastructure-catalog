# =============================================================================
# LightWave App Deployer Image
# =============================================================================
#
# This image combines Kaniko (for building) with AWS CLI (for deploying).
# Used by the ECS Deploy Runner for app_deployer tasks.
# =============================================================================

FROM gcr.io/kaniko-project/executor:latest AS kaniko

FROM amazon/aws-cli:latest

# Install required tools
RUN yum install -y git jq tar gzip && \
    yum clean all

# Copy Kaniko executor
COPY --from=kaniko /kaniko/executor /kaniko/executor

# Copy deployment scripts
COPY deploy.sh /deploy.sh
RUN chmod +x /deploy.sh

# Set environment
ENV AWS_REGION=us-east-1

ENTRYPOINT ["/deploy.sh"]
