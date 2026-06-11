package com.circleguard.notification.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "features")
public class FeatureFlags {

    private Push push = new Push();

    public Push getPush() { return push; }
    public void setPush(Push push) { this.push = push; }

    public static class Push {
        /** When true, push notifications are dispatched to the real Gotify server.
         *  When false (default), MockPushServiceImpl logs them without network calls. */
        private boolean realDelivery = false;

        public boolean isRealDelivery() { return realDelivery; }
        public void setRealDelivery(boolean realDelivery) { this.realDelivery = realDelivery; }
    }
}
