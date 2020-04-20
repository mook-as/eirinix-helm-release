FROM opensuse/leap

COPY --from=hairyhenderson/gomplate:v3 /gomplate /usr/local/bin/gomplate
ADD loggregator-bridge-setup.sh /usr/local/bin
RUN chmod a+x /usr/local/bin/loggregator-bridge-setup.sh
ENTRYPOINT /usr/local/bin/loggregator-bridge-setup.sh
