FROM ubuntu:22.04

ARG SSH_USER=sshuser
ARG SSH_PASSWORD=sshpass

RUN apt-get update && apt-get install -y \
    openssh-server \
    file \
    unzip \
    tar \
    gzip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && useradd -m -s /bin/bash "$SSH_USER" \
    && echo "$SSH_USER:$SSH_PASSWORD" | chpasswd \
    && sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Copy application files
COPY move-pattern-matching-logs.sh /home/${SSH_USER}/
COPY test-move-pattern-matching-logs.sh /home/${SSH_USER}/
COPY input /home/${SSH_USER}/input

# Set ownership and permissions
RUN chown -R ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/ && \
    chmod +x /home/${SSH_USER}/move-pattern-matching-logs.sh && \
    chmod +x /home/${SSH_USER}/test-move-pattern-matching-logs.sh && \
    mkdir -p /home/${SSH_USER}/shared-output

WORKDIR /home/${SSH_USER}

# Volume for shared output
VOLUME ["/home/${SSH_USER}/shared-output"]

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
