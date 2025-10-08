package com.litten.common.config;

//import org.springframework.amqp.rabbit.annotation.EnableRabbit;
//import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
//import org.springframework.amqp.rabbit.connection.CachingConnectionFactory;
//import org.springframework.amqp.rabbit.connection.ConnectionFactory;
//import org.springframework.amqp.rabbit.core.RabbitTemplate;
//import org.springframework.beans.factory.annotation.Qualifier;
//import org.springframework.context.annotation.Bean;
//import org.springframework.context.annotation.Configuration;
//import org.springframework.context.annotation.Profile;

//@Configuration
//@EnableRabbit
public class ConfMq {
//    @Profile({"local"})
//    @Bean(name="connectionFactory")
//    CachingConnectionFactory connectionFactoryLocal() {
//        CachingConnectionFactory connectionFactory = new CachingConnectionFactory();
//        connectionFactory.setUri("amqp://3.34.145.169:9091");
//        connectionFactory.setUsername("account");
//        connectionFactory.setPassword("ploonet123!");
//        connectionFactory.setVirtualHost("/");
//        return connectionFactory;
//    }
//
//    @Profile({"dev"})
//    @Bean(name="connectionFactory")
//    CachingConnectionFactory connectionFactoryDev() {
//        CachingConnectionFactory connectionFactory = new CachingConnectionFactory();
//        connectionFactory.setUri("amqp://10.0.11.30:9091");
//        connectionFactory.setUsername("account");
//        connectionFactory.setPassword("ploonet123!");
//        connectionFactory.setVirtualHost("/");
//        return connectionFactory;
//    }
//
//    @Profile({"release"})
//    @Bean(name="connectionFactory")
//    CachingConnectionFactory connectionFactoryRelease() {
//        CachingConnectionFactory connectionFactory = new CachingConnectionFactory();
//        connectionFactory.setUri("amqps://b-0c0c2b74-7205-4103-a978-29d00261d536.mq.ap-northeast-2.amazonaws.com:5671");
//        connectionFactory.setUsername("account");
//        connectionFactory.setPassword("ploonet123!");
//        connectionFactory.setVirtualHost("/");
//        return connectionFactory;
//    }
//
//    @Profile({"idc","idc2","prod"})
//    @Bean(name="connectionFactory")
//    CachingConnectionFactory connectionFactoryProd() {
//        CachingConnectionFactory connectionFactory = new CachingConnectionFactory();
//        connectionFactory.setUri("amqps://b-5e51f9b1-3710-48e1-9ecc-01b824d2e3b0.mq.ap-northeast-2.amazonaws.com:5671");
//        connectionFactory.setUsername("account");
//        connectionFactory.setPassword("ploonet123!");
//        connectionFactory.setVirtualHost("/");
//        return connectionFactory;
//    }
//
//    @Bean
//    public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
//        @Qualifier("connectionFactory") ConnectionFactory connectionFactory
//    ) {
//        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
//        factory.setConnectionFactory(connectionFactory);
////        factory.setConcurrentConsumers(1);
////        factory.setMaxConcurrentConsumers(7);
////        factory.setAcknowledgeMode(AcknowledgeMode.MANUAL);
//        factory.setPrefetchCount(1);
//        return factory;
//    }
//
//    @Bean(name="rabbitTemplate")
//    public RabbitTemplate rabbitTemplate(
//        @Qualifier("connectionFactory") ConnectionFactory connectionFactory
//    ) {
//        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
//        return rabbitTemplate;
//    }
}
