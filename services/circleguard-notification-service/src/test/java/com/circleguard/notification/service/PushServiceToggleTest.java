package com.circleguard.notification.service;

import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import static org.assertj.core.api.Assertions.assertThat;

// @Async wraps beans in JDK dynamic proxies (not CGLIB), so asserting isInstanceOf
// on the proxy directly fails. AopUtils.getTargetClass unwraps to the real class.
class PushServiceToggleTest {

    @SpringBootTest
    @TestPropertySource(properties = {
        "features.push.real-delivery=false",
        "spring.kafka.bootstrap-servers=localhost:19092"
    })
    static class MockBeanIsInjectedWhenToggleOff {
        @Autowired
        private PushService pushService;

        @Test
        void mockImplementationIsActive() {
            assertThat(AopUtils.getTargetClass(pushService)).isEqualTo(MockPushServiceImpl.class);
        }
    }

    @SpringBootTest
    @TestPropertySource(properties = {
        "features.push.real-delivery=true",
        "push.gotify.url=http://localhost:19999",
        "push.gotify.token=test-token",
        "spring.kafka.bootstrap-servers=localhost:19092"
    })
    static class RealBeanIsInjectedWhenToggleOn {
        @Autowired
        private PushService pushService;

        @Test
        void realImplementationIsActive() {
            assertThat(AopUtils.getTargetClass(pushService)).isEqualTo(PushServiceImpl.class);
        }
    }
}
