FROM opensearchproject/opensearch:3.8.0

# todo: LTR
#ARG ltrversion=2.1.0
#RUN /usr/share/opensearch/bin/opensearch-plugin install -b https://github.com/gsingers/opensearch-learning-to-rank-base/releases/download/release-v${ltrversion}/ltr-plugin-v${ltrversion}.zip

# todo: Querqy
COPY opensearch-querqy-1.2.os3.8.0.zip /tmp/
RUN /usr/share/opensearch/bin/opensearch-plugin install -b "file:///tmp/opensearch-querqy-1.2.os3.8.0.zip"
