# Use a Python base image
FROM python:3.10-slim

# Install cron and necessary utilities
RUN apt-get update && apt-get install -y cron

# Set the working directory
WORKDIR /app

# Install Poetry
RUN pip install poetry

# Copy your Python script and poetry files (if any) to the container
COPY . /app

# Install dependencies using Poetry
RUN poetry install

# Add a cron job entry in a new file
RUN echo "SHELL=/bin/bash\n" > /etc/cron.d/my-cron-job
RUN echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n" >> /etc/cron.d/my-cron-job

# Set default values for environment variables
ENV CRON_STRING="5 6 * * *" \
    IPMI_URL="" \
    KEY_FILE="/cert/privkey.pem" \
    CERT_FILE="/cert/cert.pem" \
    USERNAME="" \
    PASSWORD="" \
    NO_REBOOT="false" \
    LEAD_TIME_DAYS="7" \
    DEBUG="false"

# Create a script to run your Python program with arguments
RUN echo "cd /app && poetry run python main.py --ipmi-url \$IPMI_URL --key-file \$KEY_FILE --cert-file \$CERT_FILE --username \$USERNAME --password \$PASSWORD --no-reboot \$NO_REBOOT --lead-time-days \$LEAD_TIME_DAYS --debug \$DEBUG" > /run_cert_update.sh
RUN chmod +x /run_cert_update.sh

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN which poetry
# Set the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]

